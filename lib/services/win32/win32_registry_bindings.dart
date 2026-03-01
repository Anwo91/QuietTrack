part of '../win32_service.dart';

final _advapi32 = DynamicLibrary.open('advapi32.dll');

// RegOpenKeyExW
typedef _RegOpenKeyExNative = Int32 Function(
    IntPtr hKey, Pointer<Utf16> lpSubKey, Uint32 ulOptions,
    Uint32 samDesired, Pointer<IntPtr> phkResult);
typedef _RegOpenKeyExDart = int Function(
    int hKey, Pointer<Utf16> lpSubKey, int ulOptions,
    int samDesired, Pointer<IntPtr> phkResult);
final _regOpenKeyEx = _advapi32
    .lookupFunction<_RegOpenKeyExNative, _RegOpenKeyExDart>('RegOpenKeyExW');

// RegSetValueExW
typedef _RegSetValueExNative = Int32 Function(
    IntPtr hKey, Pointer<Utf16> lpValueName, Uint32 reserved,
    Uint32 dwType, Pointer<Uint8> lpData, Uint32 cbData);
typedef _RegSetValueExDart = int Function(
    int hKey, Pointer<Utf16> lpValueName, int reserved,
    int dwType, Pointer<Uint8> lpData, int cbData);
final _regSetValueEx = _advapi32
    .lookupFunction<_RegSetValueExNative, _RegSetValueExDart>('RegSetValueExW');

// RegDeleteValueW
typedef _RegDeleteValueNative = Int32 Function(
    IntPtr hKey, Pointer<Utf16> lpValueName);
typedef _RegDeleteValueDart = int Function(
    int hKey, Pointer<Utf16> lpValueName);
final _regDeleteValue = _advapi32
    .lookupFunction<_RegDeleteValueNative, _RegDeleteValueDart>('RegDeleteValueW');

// RegCloseKey
typedef _RegCloseKeyNative = Int32 Function(IntPtr hKey);
typedef _RegCloseKeyDart = int Function(int hKey);
final _regCloseKey = _advapi32
    .lookupFunction<_RegCloseKeyNative, _RegCloseKeyDart>('RegCloseKey');
