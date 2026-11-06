<#
.SYNOPSIS
Returns whether any Windows microphone/capture endpoint is currently in use.
.DESCRIPTION
Returns a single Boolean: True when a capture session is running, otherwise False.
Checks all enabled capture devices, not just the default microphone. Silent or
muted input still counts as use; playback sessions do not. This is a point-in-time
check, not a monitor. Windows audio/COM failures are terminating errors, not False.
The check does not open a recording stream or inspect application identities.
.EXAMPLE
.\check-microphone.ps1
#>

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Microphone usage detection requires Windows.'
}

if (-not ('MicrophoneUsage.Detector' -as [type])) {
    Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace MicrophoneUsage
{
    public static class Detector
    {
        public static bool IsInUse()
        {
            IMMDeviceEnumerator enumerator = null;
            IMMDeviceCollection devices = null;
            try
            {
                enumerator = (IMMDeviceEnumerator)Activator.CreateInstance(
                    Type.GetTypeFromCLSID(new Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")));
                // eCapture = 1; DEVICE_STATE_ACTIVE = 1 (enabled, not necessarily in use).
                Marshal.ThrowExceptionForHR(enumerator.EnumAudioEndpoints(1, 1, out devices));
                uint count;
                Marshal.ThrowExceptionForHR(devices.GetCount(out count));

                for (uint index = 0; index < count; index++)
                {
                    IMMDevice device = null;
                    try
                    {
                        Marshal.ThrowExceptionForHR(devices.Item(index, out device));
                        if (HasRunningSession(device))
                            return true;
                    }
                    finally
                    {
                        Release(device);
                    }
                }

                return false;
            }
            finally
            {
                Release(devices);
                Release(enumerator);
            }
        }

        private static bool HasRunningSession(IMMDevice device)
        {
            object managerObject = null;
            IAudioSessionEnumerator sessions = null;
            try
            {
                Guid managerId = typeof(IAudioSessionManager2).GUID;
                // CLSCTX_ALL = 23.
                Marshal.ThrowExceptionForHR(device.Activate(ref managerId, 23,
                    IntPtr.Zero, out managerObject));
                IAudioSessionManager2 manager = (IAudioSessionManager2)managerObject;
                Marshal.ThrowExceptionForHR(manager.GetSessionEnumerator(out sessions));
                int count;
                Marshal.ThrowExceptionForHR(sessions.GetCount(out count));

                for (int index = 0; index < count; index++)
                {
                    IAudioSessionControl session = null;
                    try
                    {
                        Marshal.ThrowExceptionForHR(sessions.GetSession(index, out session));
                        int state;
                        Marshal.ThrowExceptionForHR(session.GetState(out state));
                        // AudioSessionStateActive = 1, independent of input volume.
                        if (state == 1)
                            return true;
                    }
                    finally
                    {
                        Release(session);
                    }
                }

                return false;
            }
            finally
            {
                Release(sessions);
                Release(managerObject);
            }
        }

        private static void Release(object value)
        {
            if (value != null)
                Marshal.ReleaseComObject(value);
        }

        // Only the COM vtable prefixes used above are declared, in native order.
        [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"),
         InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        private interface IMMDeviceEnumerator
        {
            [PreserveSig]
            int EnumAudioEndpoints(int dataFlow, uint stateMask, out IMMDeviceCollection devices);
        }

        [ComImport, Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"),
         InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        private interface IMMDeviceCollection
        {
            [PreserveSig]
            int GetCount(out uint count);
            [PreserveSig]
            int Item(uint index, out IMMDevice device);
        }

        [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"),
         InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        private interface IMMDevice
        {
            [PreserveSig]
            int Activate(ref Guid iid, uint context, IntPtr activationParameters,
                [MarshalAs(UnmanagedType.IUnknown)] out object instance);
        }

        [ComImport, Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"),
         InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        private interface IAudioSessionManager2
        {
            [PreserveSig]
            int GetAudioSessionControl(ref Guid sessionId, uint flags, out IntPtr control);
            [PreserveSig]
            int GetSimpleAudioVolume(ref Guid sessionId, uint flags, out IntPtr volume);
            [PreserveSig]
            int GetSessionEnumerator(out IAudioSessionEnumerator sessions);
        }

        [ComImport, Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"),
         InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        private interface IAudioSessionEnumerator
        {
            [PreserveSig]
            int GetCount(out int count);
            [PreserveSig]
            int GetSession(int index, out IAudioSessionControl session);
        }

        [ComImport, Guid("F4B1A599-7266-4319-A8CA-E70ACB11E8CD"),
         InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        private interface IAudioSessionControl
        {
            [PreserveSig]
            int GetState(out int state);
        }
    }
}
'@
}

try {
    [MicrophoneUsage.Detector]::IsInUse()
}
catch {
    throw
}