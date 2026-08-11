#Requires -Version 5.1
<#
.SYNOPSIS
    1. Switches ClearType to BGR when any display is rotated 180°.
    2. Disables Precision Touchpad when device enters slate (tablet) mode.
    Event-driven via hidden NativeWindow + WM_DISPLAYCHANGE / WM_SETTINGCHANGE.
#>

Add-Type -TypeDefinition @"
using System;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using Microsoft.Win32;

public class Win32Notify
{
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SendMessageTimeout(IntPtr hWnd, int Msg,
        IntPtr wParam, string lParam, int fuFlags, int uTimeout, out IntPtr lpdwResult);
    public static readonly IntPtr HWND_BROADCAST = new IntPtr(0xffff);
    public const int WM_SETTINGCHANGE = 0x1A;
    public const int SMTO_ABORTIFHUNG = 0x0002;
}

public class DisplayChangeListener : NativeWindow
{
    private const int WM_DISPLAYCHANGE = 0x007E;
    private const int WM_SETTINGCHANGE = 0x001A;
    private const int SM_CONVERTIBLESLATEMODE = 0x2003;

    private const uint SPI_SETFONTSMOOTHINGORIENTATION = 0x2013;
    private const uint SPI_SETFONTSMOOTHINGTYPE = 0x200B;
    private const uint SPIF_UPDATEINIFILE = 0x01;
    private const uint SPIF_SENDCHANGE = 0x02;

    private const int ENUM_CURRENT_SETTINGS = -1;
    private const int DMDO_180 = 2;
    private const int DISPLAY_DEVICE_ATTACHED_TO_DESKTOP = 0x00000001;

    private const uint BGR = 0x0000;
    private const uint RGB = 0x0001;
    private const uint FE_FONTSMOOTHINGCLEARTYPE = 0x0002;

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SystemParametersInfoW(uint uiAction, uint uiParam, uint pvParam, uint fWinIni);

    [DllImport("user32.dll")]
    private static extern int GetSystemMetrics(int nIndex);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    private static extern bool EnumDisplayDevices(string lpDevice, uint iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, uint dwFlags);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    private static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct DISPLAY_DEVICE
    {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]  public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct DEVMODE
    {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
        public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra;
        public int dmFields, dmPositionX, dmPositionY;
        public int dmDisplayOrientation;
        public int dmDisplayFixedOutput;
        public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
        public short dmLogPixels, dmBitsPerPel;
        public int dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
        public int dmICMMethod, dmICMIntent, dmMediaType, dmDitherType;
        public int dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight;
    }

    public void CreateHiddenWindow()
    {
        CreateHandle(new CreateParams
        {
            ExStyle = unchecked((int)0x80),
            Style   = unchecked((int)0x80000000)
        });
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == WM_DISPLAYCHANGE)
        {
            UpdateClearType();
        }
        else if (m.Msg == WM_SETTINGCHANGE)
        {
            if (m.LParam != IntPtr.Zero)
            {
                string setting = Marshal.PtrToStringUni(m.LParam);
                if (setting == "ConvertibleSlateMode")
                {
                    bool slateMode = (GetSystemMetrics(SM_CONVERTIBLESLATEMODE) == 0);
                    SetTouchpadEnabled(!slateMode);
                }
            }
        }
        base.WndProc(ref m);
    }

    private bool IsAnyDisplayRotated180()
    {
        uint devNum = 0;
        DISPLAY_DEVICE device = new DISPLAY_DEVICE();
        device.cb = Marshal.SizeOf(device);

        while (EnumDisplayDevices(null, devNum, ref device, 0))
        {
            if ((device.StateFlags & DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) != 0)
            {
                DEVMODE dm = new DEVMODE();
                dm.dmSize = (short)Marshal.SizeOf(dm);
                if (EnumDisplaySettings(device.DeviceName, ENUM_CURRENT_SETTINGS, ref dm))
                {
                    if (dm.dmDisplayOrientation == DMDO_180)
                        return true;
                }
            }
            devNum++;
        }
        return false;
    }

    private string[] GetDisplayNames()
    {
        var names = new System.Collections.Generic.List<string>();
        foreach (var screen in System.Windows.Forms.Screen.AllScreens)
        {
            int idx = screen.DeviceName.LastIndexOf("\\");
            names.Add(idx >= 0 ? screen.DeviceName.Substring(idx + 1) : screen.DeviceName);
        }
        return names.ToArray();
    }

    public void UpdateClearType()
    {
        bool needBGR = IsAnyDisplayRotated180();
        uint orientation = needBGR ? BGR : RGB;

        SystemParametersInfoW(SPI_SETFONTSMOOTHINGTYPE, 0, FE_FONTSMOOTHINGCLEARTYPE, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
        SystemParametersInfoW(SPI_SETFONTSMOOTHINGORIENTATION, 0, orientation, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);

        Registry.SetValue(@"HKEY_CURRENT_USER\Control Panel\Desktop",
                          "FontSmoothingOrientation",
                          (int)orientation,
                          RegistryValueKind.DWord);

        int pixelStructure = needBGR ? 2 : 1;
        int contrast = 1200;
        int clearTypeLevel = 100;

        foreach (string displayName in GetDisplayNames())
        {
            SetRegDword(Registry.LocalMachine, @"Software\Microsoft\Avalon.Graphics\" + displayName, "GammaLevel", contrast);
            SetRegDword(Registry.LocalMachine, @"Software\Microsoft\Avalon.Graphics\" + displayName, "PixelStructure", pixelStructure);

            SetRegDword(Registry.CurrentUser, @"Software\Microsoft\Avalon.Graphics\" + displayName, "ClearTypeLevel", clearTypeLevel);
            SetRegDword(Registry.CurrentUser, @"Software\Microsoft\Avalon.Graphics\" + displayName, "EnhancedContrastLevel", 50);
            SetRegDword(Registry.CurrentUser, @"Software\Microsoft\Avalon.Graphics\" + displayName, "GammaLevel", contrast);
            SetRegDword(Registry.CurrentUser, @"Software\Microsoft\Avalon.Graphics\" + displayName, "GrayscaleEnhancedContrastLevel", 100);
            SetRegDword(Registry.CurrentUser, @"Software\Microsoft\Avalon.Graphics\" + displayName, "PixelStructure", pixelStructure);
            SetRegDword(Registry.CurrentUser, @"Software\Microsoft\Avalon.Graphics\" + displayName, "TextContrastLevel", 1);
        }

        IntPtr result = IntPtr.Zero;
        Win32Notify.SendMessageTimeout(
            Win32Notify.HWND_BROADCAST,
            Win32Notify.WM_SETTINGCHANGE,
            IntPtr.Zero,
            "Environment",
            Win32Notify.SMTO_ABORTIFHUNG,
            5000,
            out result);

        Console.WriteLine("[{0:HH:mm:ss}] ClearType: {1}",
                          DateTime.Now,
                          needBGR ? "180 deg -> BGR" : "Normal -> RGB");
    }

    public void SetTouchpadEnabled(bool enabled)
    {
        Registry.SetValue(
            @"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\PrecisionTouchPad\Status",
            "Enabled",
            enabled ? 1 : 0,
            RegistryValueKind.DWord);

        IntPtr result = IntPtr.Zero;
        Win32Notify.SendMessageTimeout(
            Win32Notify.HWND_BROADCAST,
            Win32Notify.WM_SETTINGCHANGE,
            IntPtr.Zero,
            "Environment",
            Win32Notify.SMTO_ABORTIFHUNG,
            5000,
            out result);

        Console.WriteLine("[{0:HH:mm:ss}] Touchpad: {1}",
                          DateTime.Now,
                          enabled ? "Enabled" : "Disabled");
    }

    private void SetRegDword(RegistryKey baseKey, string keyPath, string name, int value)
    {
        try
        {
            using (RegistryKey key = baseKey.CreateSubKey(keyPath))
                key.SetValue(name, value, RegistryValueKind.DWord);
        }
        catch { }
    }
}
"@ -ReferencedAssemblies System.Windows.Forms, System.Drawing

# -- Start listener ----------------------------------------------------
$listener = New-Object DisplayChangeListener
$listener.CreateHiddenWindow()
$listener.UpdateClearType()

# Initial touchpad sync based on current slate mode
Add-Type -Name SlateCheck -Namespace Win32 -MemberDefinition @'
[DllImport("user32.dll")]
public static extern int GetSystemMetrics(int nIndex);
public const int SM_CONVERTIBLESLATEMODE = 0x2003;
'@ -ErrorAction SilentlyContinue

$isSlate = ([Win32.SlateCheck]::GetSystemMetrics([Win32.SlateCheck]::SM_CONVERTIBLESLATEMODE) -eq 0)
$listener.SetTouchpadEnabled(-not $isSlate)

Write-Host "Hidden window created. Listening for WM_DISPLAYCHANGE and ConvertibleSlateMode. Close window to stop."

[System.Windows.Forms.Application]::Run((New-Object System.Windows.Forms.ApplicationContext))