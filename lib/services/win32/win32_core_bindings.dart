part of '../win32_service.dart';

final _kernel32 = DynamicLibrary.open('kernel32.dll');
final _user32 = DynamicLibrary.open('user32.dll');

typedef _QueryFullProcessImageNameNative = Int32 Function(
    IntPtr hProcess, Uint32 dwFlags, Pointer<Utf16> lpExeName, Pointer<Uint32> lpdwSize);
typedef _QueryFullProcessImageNameDart = int Function(
    int hProcess, int dwFlags, Pointer<Utf16> lpExeName, Pointer<Uint32> lpdwSize);

final _queryFullProcessImageName = _kernel32.lookupFunction<
    _QueryFullProcessImageNameNative,
    _QueryFullProcessImageNameDart>('QueryFullProcessImageNameW');

typedef _GetTickCountNative = Uint32 Function();
typedef _GetTickCountDart = int Function();
final _getTickCount =
    _kernel32.lookupFunction<_GetTickCountNative, _GetTickCountDart>('GetTickCount');

typedef _GetLastInputInfoNative = Int32 Function(Pointer<LASTINPUTINFO> plii);
typedef _GetLastInputInfoDart = int Function(Pointer<LASTINPUTINFO> plii);
final _getLastInputInfo =
    _user32.lookupFunction<_GetLastInputInfoNative, _GetLastInputInfoDart>('GetLastInputInfo');

typedef _GetForegroundWindowNative = IntPtr Function();
typedef _GetForegroundWindowDart = int Function();
final _getForegroundWindow =
    _user32.lookupFunction<_GetForegroundWindowNative, _GetForegroundWindowDart>(
        'GetForegroundWindow');

typedef _GetWindowThreadProcessIdNative = Uint32 Function(
    IntPtr hWnd, Pointer<Uint32> lpdwProcessId);
typedef _GetWindowThreadProcessIdDart = int Function(
    int hWnd, Pointer<Uint32> lpdwProcessId);
final _getWindowThreadProcessId = _user32.lookupFunction<
    _GetWindowThreadProcessIdNative,
    _GetWindowThreadProcessIdDart>('GetWindowThreadProcessId');

typedef _GetWindowTextWNative = Int32 Function(
    IntPtr hWnd, Pointer<Utf16> lpString, Int32 nMaxCount);
typedef _GetWindowTextWDart = int Function(
    int hWnd, Pointer<Utf16> lpString, int nMaxCount);
final _getWindowText =
    _user32.lookupFunction<_GetWindowTextWNative, _GetWindowTextWDart>('GetWindowTextW');

typedef _GetWindowTextLengthWNative = Int32 Function(IntPtr hWnd);
typedef _GetWindowTextLengthWDart = int Function(int hWnd);
final _getWindowTextLength = _user32.lookupFunction<
    _GetWindowTextLengthWNative, _GetWindowTextLengthWDart>('GetWindowTextLengthW');

typedef _OpenProcessNative = IntPtr Function(
    Uint32 dwDesiredAccess, Int32 bInheritHandle, Uint32 dwProcessId);
typedef _OpenProcessDart = int Function(
    int dwDesiredAccess, int bInheritHandle, int dwProcessId);
final _openProcess =
    _kernel32.lookupFunction<_OpenProcessNative, _OpenProcessDart>('OpenProcess');

typedef _CloseHandleNative = Int32 Function(IntPtr hObject);
typedef _CloseHandleDart = int Function(int hObject);
final _closeHandle =
    _kernel32.lookupFunction<_CloseHandleNative, _CloseHandleDart>('CloseHandle');
