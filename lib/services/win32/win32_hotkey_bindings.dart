part of '../win32_service.dart';

typedef _RegisterHotKeyNative = Int32 Function(
    IntPtr hWnd, Int32 id, Uint32 fsModifiers, Uint32 vk);
typedef _RegisterHotKeyDart = int Function(int hWnd, int id, int fsModifiers, int vk);
final _registerHotKey =
    _user32.lookupFunction<_RegisterHotKeyNative, _RegisterHotKeyDart>('RegisterHotKey');

typedef _UnregisterHotKeyNative = Int32 Function(IntPtr hWnd, Int32 id);
typedef _UnregisterHotKeyDart = int Function(int hWnd, int id);
final _unregisterHotKey =
    _user32.lookupFunction<_UnregisterHotKeyNative, _UnregisterHotKeyDart>(
        'UnregisterHotKey');

typedef _PeekMessageWNative = Int32 Function(
    Pointer<MSG> lpMsg, IntPtr hWnd, Uint32 wMsgFilterMin, Uint32 wMsgFilterMax, Uint32 wRemoveMsg);
typedef _PeekMessageWDart = int Function(
    Pointer<MSG> lpMsg, int hWnd, int wMsgFilterMin, int wMsgFilterMax, int wRemoveMsg);
final _peekMessage =
    _user32.lookupFunction<_PeekMessageWNative, _PeekMessageWDart>('PeekMessageW');
