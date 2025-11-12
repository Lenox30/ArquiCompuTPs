#!/usr/bin/env python3
"""
==============================================================================
Script de Testing para UART ALU Top
==============================================================================
Requisitos:
    pip install pyserial

Uso:
    python uart_alu_test.py COM3
==============================================================================
"""

import sys
import time
from typing import Tuple
import serial

# Configuración UART
BAUD_RATE = 9600
TIMEOUT = 2.0
DEBUG = True  # Habilitar prints de depuración

# Códigos de operación
OP_ADD = 0b100000
OP_SUB = 0b100010
OP_AND = 0b100100
OP_OR  = 0b100101
OP_XOR = 0b100110
OP_NOR = 0b100111
OP_SRL = 0b000010
OP_SRA = 0b000011

class UARTALUTester:
    def __init__(self, port: str):
        """Inicializar conexión serial"""
        try:
            self.ser = serial.Serial(
                port=port,
                baudrate=BAUD_RATE,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=TIMEOUT,
                write_timeout=2.0
            )
            print(f"✓ Conectado a {port} @ {BAUD_RATE} baudios")
            time.sleep(2)  # Esperar inicialización de FPGA
            
            # Limpiar buffers
            self.ser.reset_input_buffer()
            self.ser.reset_output_buffer()
            time.sleep(0.1)
            
        except serial.SerialException as e:
            print(f"✗ Error al conectar: {e}")
            sys.exit(1)
    
    def send_operation(self, a: int, b: int, op: int) -> Tuple[int, int, int]:
        """
        Enviar operación a la FPGA y recibir respuesta
        CON TIMING CORRECTO
        
        Args:
            a: Operando A (0-255)
            b: Operando B (0-255)
            op: Código de operación (6 bits)
        
        Returns:
            (resultado, flags, status)
        """
        # Limpiar buffers antes de cada operación
        self.ser.reset_input_buffer()
        self.ser.reset_output_buffer()
        
        # Enviar 3 bytes: A, B, OP
        to_send = bytes([a & 0xFF, b & 0xFF, op & 0x3F])  ## bytes es una función que crea un array de bytes
        if DEBUG:
            print(f"-> Enviando: {to_send.hex(' ')}") ## Muestra los bytes en hexadecimal separados por espacios    
        
        self.ser.write(to_send)
        self.ser.flush()  # Flush sirve para asegurar envío inmediato
        
        # Cálculo de tiempo:
        # - RX de 3 bytes @ 9600 baud: ~3.1 ms
        # - Procesamiento ALU: <1 ms
        # - TX de 3 bytes @ 9600 baud: ~3.1 ms
        # Total: ~6.2 ms mínimo
        # Usamos 20 ms para margen de seguridad
        time.sleep(0.020)
        
        # Recibir 3 bytes: Resultado, Flags, Status
        response = self.ser.read(3)
        if DEBUG:
            print(f"<- Recibido: {response.hex(' ') if response else '(vacio)'}")

        if len(response) != 3:
            # Debug adicional para troubleshooting
            print(f"   [DEBUG] Bytes esperados: 3")
            print(f"   [DEBUG] Bytes recibidos: {len(response)}")
            
            raise TimeoutError(f"Timeout: solo recibí {len(response)} bytes")

        result = response[0]
        flags = response[1]
        status = response[2]

        return result, flags, status
    
    def parse_flags(self, flags: int) -> dict:
        """Extraer flags individuales del byte de flags"""
        return {
            'zero': bool(flags & 0x80),      # Bit 7
            'overflow': bool(flags & 0x40),  # Bit 6
            'carry': bool(flags & 0x20)      # Bit 5
        }
    
    def test_operation(self, a: int, b: int, op: int, 
                      expected_result: int, expected_zero: bool = False,
                      expected_overflow: bool = False, expected_carry: bool = False,
                      test_name: str = "Test") -> bool:
        """
        Ejecutar un test de operación
        
        Returns:
            True si el test pasó, False si falló
        """
        try:
            result, flags_byte, status = self.send_operation(a, b, op)
            flags = self.parse_flags(flags_byte)
            
            # Verificar resultado
            result_ok = (result == expected_result)
            zero_ok = (flags['zero'] == expected_zero)
            overflow_ok = (flags['overflow'] == expected_overflow)
            carry_ok = (flags['carry'] == expected_carry)
            status_ok = (status == 0x55)
            
            passed = result_ok and zero_ok and overflow_ok and carry_ok and status_ok
            
            if passed:
                print(f"  ✓ {test_name}")
            else:
                print(f"  ✗ {test_name}")
                print(f"      Esperado: Result=0x{expected_result:02X} Z={int(expected_zero)} V={int(expected_overflow)} C={int(expected_carry)}")
                print(f"      Obtenido: Result=0x{result:02X} Z={int(flags['zero'])} V={int(flags['overflow'])} C={int(flags['carry'])}")
                if not status_ok:
                    print(f"      Status: 0x{status:02X} (esperado: 0x55)")
            
            return passed
            
        except TimeoutError as e:
            print(f"  ✗ {test_name} - {e}")
            return False
        except Exception as e:
            print(f"  ✗ {test_name} - Error: {e}")
            return False
    
    def run_test_suite(self):
        """Ejecutar suite completa de tests"""
        print("\n" + "="*70)
        print("  INICIANDO TESTS - UART ALU")
        print("="*70)
        
        passed = 0
        failed = 0
        
        # Test 1: ADD básica
        print("\n[SUITE] Operaciones Aritméticas")
        print("-"*70)
        if self.test_operation(10, 20, OP_ADD, 30, test_name="ADD: 10 + 20 = 30"):
            passed += 1
        else:
            failed += 1
        
        # Test 2: ADD con carry
        if self.test_operation(200, 100, OP_ADD, 44, expected_carry=True, 
                              test_name="ADD: 200 + 100 = 44 (con carry)"):
            passed += 1
        else:
            failed += 1
        
        # Test 3: ADD overflow
        if self.test_operation(127, 1, OP_ADD, 128, expected_overflow=True,
                              test_name="ADD: 127 + 1 = 128 (overflow)"):
            passed += 1
        else:
            failed += 1
        
        # Test 4: SUB básica
        if self.test_operation(50, 30, OP_SUB, 20, test_name="SUB: 50 - 30 = 20"):
            passed += 1
        else:
            failed += 1
        
        # Test 5: AND
        print("\n[SUITE] Operaciones Lógicas")
        print("-"*70)
        if self.test_operation(0xF0, 0xAA, OP_AND, 0xA0, test_name="AND: 0xF0 & 0xAA = 0xA0"):
            passed += 1
        else:
            failed += 1
        
        # Test 6: OR
        if self.test_operation(0xF0, 0x0F, OP_OR, 0xFF, test_name="OR: 0xF0 | 0x0F = 0xFF"):
            passed += 1
        else:
            failed += 1
        
        # Test 7: XOR con zero flag
        if self.test_operation(0xAA, 0xAA, OP_XOR, 0x00, expected_zero=True,
                              test_name="XOR: 0xAA ^ 0xAA = 0x00 (zero)"):
            passed += 1
        else:
            failed += 1
        
        # Test 8: SRL
        print("\n[SUITE] Operaciones de Shift")
        print("-"*70)
        if self.test_operation(0xF0, 2, OP_SRL, 0x3C, test_name="SRL: 0xF0 >> 2 = 0x3C"):
            passed += 1
        else:
            failed += 1
        
        # Test 9: SRA (mantiene signo)
        if self.test_operation(0xF0, 2, OP_SRA, 0xFC, test_name="SRA: 0xF0 >>> 2 = 0xFC"):
            passed += 1
        else:
            failed += 1
        
        # Test 10: Stress test
        print("\n[SUITE] Stress Test - Operaciones Consecutivas")
        print("-"*70)
        for i in range(5):
            val = 1 << i  # 1, 2, 4, 8, 16
            if self.test_operation(val, val, OP_ADD, (val*2) & 0xFF, 
                                  test_name=f"ADD: {val} + {val} = {val*2}"):
                passed += 1
            else:
                failed += 1
        
        # Reporte final
        print("\n" + "="*70)
        print("  REPORTE FINAL")
        print("="*70)
        total = passed + failed
        print(f"Tests ejecutados: {total}")
        print(f"Tests PASADOS:    {passed}")
        print(f"Tests FALLADOS:   {failed}")
        print(f"Tasa de éxito:    {(passed/total)*100:.1f}%")
        print("="*70)
        
        if failed == 0:
            print("\n✓✓✓ TODOS LOS TESTS PASARON ✓✓✓\n")
        else:
            print(f"\n✗ {failed} tests fallaron - Revisar implementación\n")
        
        return failed == 0
    
    def interactive_mode(self):
        """Modo interactivo para testing manual"""
        print("\n" + "="*70)
        print("  MODO INTERACTIVO")
        print("="*70)
        print("Comandos:")
        print("  add <a> <b>    - Sumar A + B")
        print("  sub <a> <b>    - Restar A - B")
        print("  and <a> <b>    - AND lógico")
        print("  or <a> <b>     - OR lógico")
        print("  xor <a> <b>    - XOR lógico")
        print("  nor <a> <b>    - NOR lógico")
        print("  srl <a> <b>    - Shift right logical")
        print("  sra <a> <b>    - Shift right arithmetic")
        print("  quit           - Salir")
        print("-"*70)
        
        ops = {
            'add': OP_ADD, 'sub': OP_SUB, 'and': OP_AND, 'or': OP_OR,
            'xor': OP_XOR, 'nor': OP_NOR, 'srl': OP_SRL, 'sra': OP_SRA
        }
        
        while True:
            try:
                cmd = input("\n> ").strip().lower().split()
                
                if not cmd:
                    continue
                
                if cmd[0] == 'quit':
                    break
                
                if cmd[0] not in ops:
                    print("Comando inválido")
                    continue
                
                if len(cmd) != 3:
                    print("Uso: <operación> <a> <b>")
                    continue
                
                a = int(cmd[1]) & 0xFF
                b = int(cmd[2]) & 0xFF
                op = ops[cmd[0]]
                
                result, flags_byte, status = self.send_operation(a, b, op)
                flags = self.parse_flags(flags_byte)
                
                print(f"  Resultado: 0x{result:02X} ({result})")
                print(f"  Flags: Z={int(flags['zero'])} V={int(flags['overflow'])} C={int(flags['carry'])}")
                print(f"  Status: 0x{status:02X}")
                
            except KeyboardInterrupt:
                print("\n\nInterrumpido por usuario")
                break
            except Exception as e:
                print(f"Error: {e}")
    
    def close(self):
        """Cerrar conexión serial"""
        if self.ser.is_open:
            self.ser.close()
            print("✓ Conexión cerrada")

def main():
    if len(sys.argv) < 2:
        print("Uso: python uart_alu_test.py <puerto> [modo]")
        print("  Windows: python uart_alu_test.py COM3")
        print("  Linux:   python uart_alu_test.py /dev/ttyUSB0")
        print("  Modo interactivo: python uart_alu_test.py COM3 interactive")
        sys.exit(1)
    
    port = sys.argv[1] 
    mode = sys.argv[2] if len(sys.argv) > 2 else "test"
    
    tester = UARTALUTester(port)
    
    try:
        if mode == "interactive":
            tester.interactive_mode()
        else:
            success = tester.run_test_suite()
            sys.exit(0 if success else 1)
    finally:
        tester.close()

if __name__ == "__main__":
    main()