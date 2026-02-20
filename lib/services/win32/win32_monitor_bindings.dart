part of '../win32_service.dart';

const _displayDeviceSize = 840;
const _pathInfoSize = 72;
const _modeInfoSize = 64;
const _targetDeviceNameSize = 420;
const _sourceDeviceNameSize = 84;
const _qdcOnlyActivePaths = 2;
const _deviceInfoGetTargetName = 2;

typedef _MonitorFromWindowNative = IntPtr Function(IntPtr hwnd, Uint32 dwFlags);
typedef _MonitorFromWindowDart = int Function(int hwnd, int dwFlags);
final _monitorFromWindow =
    _user32.lookupFunction<_MonitorFromWindowNative, _MonitorFromWindowDart>('MonitorFromWindow');

typedef _GetMonitorInfoWNative = Int32 Function(
    IntPtr hMonitor, Pointer<MONITORINFO> lpmi);
typedef _GetMonitorInfoWDart = int Function(int hMonitor, Pointer<MONITORINFO> lpmi);
final _getMonitorInfo =
    _user32.lookupFunction<_GetMonitorInfoWNative, _GetMonitorInfoWDart>('GetMonitorInfoW');

typedef _EnumDisplayDevicesWNative = Int32 Function(
    Pointer<Utf16> lpDevice, Uint32 iDevNum, Pointer<Uint8> lpDisplayDevice, Uint32 dwFlags);
typedef _EnumDisplayDevicesWDart = int Function(
    Pointer<Utf16> lpDevice, int iDevNum, Pointer<Uint8> lpDisplayDevice, int dwFlags);
final _enumDisplayDevices = _user32.lookupFunction<
    _EnumDisplayDevicesWNative, _EnumDisplayDevicesWDart>('EnumDisplayDevicesW');

typedef _EnumDisplayMonitorsProc = Int32 Function(
    IntPtr hMonitor, IntPtr hdcMonitor, Pointer lprcMonitor, IntPtr dwData);
typedef _EnumDisplayMonitorsNative = Int32 Function(
    IntPtr hdc,
    Pointer lprcClip,
    Pointer<NativeFunction<_EnumDisplayMonitorsProc>> lpfnEnum,
    IntPtr dwData);
typedef _EnumDisplayMonitorsDart = int Function(
    int hdc,
    Pointer lprcClip,
    Pointer<NativeFunction<_EnumDisplayMonitorsProc>> lpfnEnum,
    int dwData);
final _enumDisplayMonitors = _user32.lookupFunction<
    _EnumDisplayMonitorsNative, _EnumDisplayMonitorsDart>('EnumDisplayMonitors');

typedef _GetDisplayConfigBufferSizesNative = Int32 Function(
    Uint32 flags, Pointer<Uint32> numPathArrayElements, Pointer<Uint32> numModeInfoArrayElements);
typedef _GetDisplayConfigBufferSizesDart = int Function(
    int flags, Pointer<Uint32> numPaths, Pointer<Uint32> numModes);
final _getDisplayConfigBufferSizes = _user32.lookupFunction<
    _GetDisplayConfigBufferSizesNative,
    _GetDisplayConfigBufferSizesDart>('GetDisplayConfigBufferSizes');

typedef _QueryDisplayConfigNative = Int32 Function(
    Uint32 flags,
    Pointer<Uint32> numPaths,
    Pointer<Uint8> pathArray,
    Pointer<Uint32> numModes,
    Pointer<Uint8> modeInfoArray,
    Pointer<Uint32> currentTopologyId);
typedef _QueryDisplayConfigDart = int Function(
    int flags,
    Pointer<Uint32> numPaths,
    Pointer<Uint8> pathArray,
    Pointer<Uint32> numModes,
    Pointer<Uint8> modeInfoArray,
    Pointer<Uint32> currentTopologyId);
final _queryDisplayConfig = _user32.lookupFunction<
    _QueryDisplayConfigNative, _QueryDisplayConfigDart>('QueryDisplayConfig');

typedef _DisplayConfigGetDeviceInfoNative = Int32 Function(Pointer<Uint8> requestPacket);
typedef _DisplayConfigGetDeviceInfoDart = int Function(Pointer<Uint8> requestPacket);
final _displayConfigGetDeviceInfo = _user32.lookupFunction<
    _DisplayConfigGetDeviceInfoNative,
    _DisplayConfigGetDeviceInfoDart>('DisplayConfigGetDeviceInfo');
