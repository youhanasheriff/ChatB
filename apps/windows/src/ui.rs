//! Native controls stay on the owning thread. Bluetooth callbacks only update a
//! bounded snapshot; WM_TIMER renders it. The window procedure owns no Rust data.
use crate::{
    bluetooth::Scanner,
    options::{Mode, Options},
    state::{Network, ScanSnapshot, ScanStatus},
};
use std::time::{Duration, Instant};
use windows::{
    core::{w, Result, HSTRING},
    Win32::{
        Foundation::*,
        Graphics::Gdi::*,
        System::{LibraryLoader::GetModuleHandleW, WinRT::*},
        UI::{HiDpi::*, Input::KeyboardAndMouse::*, WindowsAndMessaging::*},
    },
};

pub struct Apartment;
impl Apartment {
    pub fn new() -> Result<Self> {
        unsafe {
            RoInitialize(RO_INIT_MULTITHREADED)?;
        }
        Ok(Self)
    }
}
impl Drop for Apartment {
    fn drop(&mut self) {
        unsafe {
            RoUninitialize();
        }
    }
}

pub fn show_error(message: &str) {
    unsafe {
        MessageBoxW(
            None,
            &HSTRING::from(message),
            w!("BitChat Desktop"),
            MB_OK | MB_ICONERROR,
        );
    }
}
const ACTION: u32 = WM_APP + 1;
const LAYOUT: u32 = WM_APP + 2;
unsafe extern "system" fn window_proc(hwnd: HWND, msg: u32, wp: WPARAM, lp: LPARAM) -> LRESULT {
    match msg {
        WM_COMMAND => {
            let _ = PostMessageW(Some(hwnd), ACTION, wp, lp);
            LRESULT(0)
        }
        WM_SIZE | WM_DPICHANGED => {
            if msg == WM_DPICHANGED {
                let rect = &*(lp.0 as *const RECT);
                let _ = SetWindowPos(
                    hwnd,
                    None,
                    rect.left,
                    rect.top,
                    rect.right - rect.left,
                    rect.bottom - rect.top,
                    SWP_NOZORDER | SWP_NOACTIVATE,
                );
            }
            let _ = PostMessageW(Some(hwnd), LAYOUT, WPARAM(0), LPARAM(0));
            LRESULT(0)
        }
        WM_GETMINMAXINFO => {
            let info = &mut *(lp.0 as *mut MINMAXINFO);
            let dpi = GetDpiForWindow(hwnd).max(96) as i32;
            info.ptMinTrackSize = POINT {
                x: 760 * dpi / 96,
                y: 560 * dpi / 96,
            };
            LRESULT(0)
        }
        WM_DESTROY => {
            PostQuitMessage(0);
            LRESULT(0)
        }
        _ => DefWindowProcW(hwnd, msg, wp, lp),
    }
}

struct Controls {
    title: HWND,
    subtitle: HWND,
    network: HWND,
    scan: HWND,
    status: HWND,
    list: HWND,
    footer: HWND,
    font: HFONT,
}
impl Controls {
    unsafe fn new(hwnd: HWND, testnet: bool) -> Result<Self> {
        let child = |class, text: &str, style, id| {
            CreateWindowExW(
                WINDOW_EX_STYLE::default(),
                class,
                &HSTRING::from(text),
                WS_CHILD | WS_VISIBLE | style,
                0,
                0,
                1,
                1,
                Some(hwnd),
                Some(HMENU(id as *mut _)),
                None,
                None,
            )
        };
        let title = child(w!("STATIC"), "Hello, nearby.", WINDOW_STYLE(0), 10)?;
        let subtitle = child(
            w!("STATIC"),
            "Windows discovery preview · Native Bluetooth LE",
            WINDOW_STYLE(0),
            11,
        )?;
        let network = child(
            w!("BUTTON"),
            "Use isolated &testnet",
            WS_TABSTOP | WINDOW_STYLE(BS_AUTOCHECKBOX as u32),
            12,
        )?;
        send_message(
            network,
            BM_SETCHECK,
            WPARAM(usize::from(testnet)),
            LPARAM(0),
        );
        let scan = child(
            w!("BUTTON"),
            "&Start scan",
            WS_TABSTOP | WINDOW_STYLE(BS_PUSHBUTTON as u32),
            13,
        )?;
        let status = child(
            w!("STATIC"),
            "Ready. Enable Bluetooth in Windows Settings, then start a 30-second scan.",
            WINDOW_STYLE(0),
            14,
        )?;
        let list = child(
            w!("LISTBOX"),
            "",
            WS_TABSTOP | WS_VSCROLL | WS_BORDER | WINDOW_STYLE(LBS_NOINTEGRALHEIGHT as u32),
            15,
        )?;
        let footer = child(w!("STATIC"), "Discovery only — no messaging, connections or verified identities.\r\nNames and addresses are untrusted advertisements. Hardware interoperability is not yet qualified.", WINDOW_STYLE(0), 16)?;
        Ok(Self {
            title,
            subtitle,
            network,
            scan,
            status,
            list,
            footer,
            font: HFONT::default(),
        })
    }
    unsafe fn layout(&mut self, hwnd: HWND) -> Result<()> {
        let dpi = GetDpiForWindow(hwnd).max(96) as i32;
        let scale = |v: i32| v * dpi / 96;
        let mut rect = RECT::default();
        GetClientRect(hwnd, &mut rect)?;
        let width = rect.right * 96 / dpi;
        let height = rect.bottom * 96 / dpi;
        let old = self.font;
        self.font = CreateFontW(
            -scale(16),
            0,
            0,
            0,
            FW_NORMAL.0 as i32,
            0,
            0,
            0,
            DEFAULT_CHARSET,
            OUT_DEFAULT_PRECIS,
            CLIP_DEFAULT_PRECIS,
            CLEARTYPE_QUALITY,
            DEFAULT_PITCH.0 as u32,
            w!("Segoe UI"),
        );
        for (control, x, y, w, h) in [
            (self.title, 28, 24, width - 56, 32),
            (self.subtitle, 28, 59, width - 56, 26),
            (self.network, 28, 104, 300, 32),
            (self.scan, width - 204, 100, 176, 40),
            (self.status, 28, 158, width - 56, 64),
            (self.list, 28, 228, width - 56, (height - 334).max(100)),
            (self.footer, 28, height - 82, width - 56, 66),
        ] {
            MoveWindow(control, scale(x), scale(y), scale(w), scale(h), true)?;
            send_message(control, WM_SETFONT, WPARAM(self.font.0 as usize), LPARAM(1));
        }
        if !old.is_invalid() {
            let _ = DeleteObject(old.into());
        }
        Ok(())
    }
    unsafe fn render(&self, snapshot: &ScanSnapshot, network: Network) -> Result<()> {
        let active = snapshot.status.is_active();
        let _ = EnableWindow(self.network, !active);
        SetWindowTextW(
            self.scan,
            &HSTRING::from(if active { "&Stop scan" } else { "&Start scan" }),
        )?;
        let status = match &snapshot.status {
            ScanStatus::Ready => {
                "Ready. Enable Bluetooth in Windows Settings, then start a 30-second scan.".into()
            }
            ScanStatus::Starting => "Starting Bluetooth discovery…".into(),
            ScanStatus::Scanning(_) => format!(
                "Scanning {} · {} matching device(s). Stops after 30 seconds.",
                network.label(),
                snapshot.devices.len()
            ),
            ScanStatus::Finished => format!(
                "Scan stopped · {} matching device(s). Results are from the last scan.",
                snapshot.devices.len()
            ),
            ScanStatus::Failed(error) => error.clone(),
        };
        SetWindowTextW(
            self.status,
            &HSTRING::from(format!(
                "{status}{}",
                if snapshot.at_capacity {
                    " Result limit: 128 devices."
                } else {
                    ""
                }
            )),
        )?;
        send_message(self.list, LB_RESETCONTENT, WPARAM(0), LPARAM(0));
        if snapshot.devices.is_empty() {
            let text = HSTRING::from("No matching devices observed.");
            send_message(
                self.list,
                LB_ADDSTRING,
                WPARAM(0),
                LPARAM(text.as_ptr() as isize),
            );
        }
        for device in snapshot.devices.values() {
            let line = HSTRING::from(format!(
                "{}  |  {}  |  {} dBm  |  unverified",
                device.name,
                device.address,
                device
                    .rssi
                    .map(|v| v.to_string())
                    .unwrap_or_else(|| "?".into())
            ));
            send_message(
                self.list,
                LB_ADDSTRING,
                WPARAM(0),
                LPARAM(line.as_ptr() as isize),
            );
        }
        Ok(())
    }
}
impl Drop for Controls {
    fn drop(&mut self) {
        unsafe {
            if !self.font.is_invalid() {
                let _ = DeleteObject(self.font.into());
            }
        }
    }
}

pub fn run(options: Options) -> Result<()> {
    let _apartment = Apartment::new()?;
    unsafe {
        let _ = SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
        let instance = GetModuleHandleW(None)?;
        let class = w!("BitChatDesktopDiscovery");
        let wc = WNDCLASSW {
            lpfnWndProc: Some(window_proc),
            hInstance: instance.into(),
            lpszClassName: class,
            hCursor: LoadCursorW(None, IDC_ARROW)?,
            hbrBackground: HBRUSH((COLOR_WINDOW.0 + 1) as *mut _),
            ..Default::default()
        };
        if RegisterClassW(&wc) == 0 {
            return Err(windows::core::Error::from_win32());
        }
        let hwnd = CreateWindowExW(
            WS_EX_CONTROLPARENT,
            class,
            w!("BitChat Desktop — Windows discovery preview"),
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            940,
            650,
            None,
            None,
            Some(instance.into()),
            None,
        )?;
        let mut controls = Controls::new(hwnd, options.network == Network::Testnet)?;
        controls.layout(hwnd)?;
        let mut network = options.network;
        let mut snapshot = ScanSnapshot::default();
        controls.render(&snapshot, network)?;
        let _ = ShowWindow(hwnd, SW_SHOW);
        if SetTimer(Some(hwnd), 1, 100, None) == 0 {
            return Err(windows::core::Error::from_win32());
        }
        let opened = Instant::now();
        let mut deadline = opened;
        let mut scanner: Option<Scanner> = None;
        let mut message = MSG::default();
        loop {
            let received = GetMessageW(&mut message, None, 0, 0).0;
            if received == -1 {
                return Err(windows::core::Error::from_win32());
            }
            if received == 0 {
                break;
            }
            if message.hwnd == hwnd {
                match message.message {
                    ACTION => match message.wParam.0 & 0xffff {
                        12 => {
                            network = if send_message(
                                controls.network,
                                BM_GETCHECK,
                                WPARAM(0),
                                LPARAM(0),
                            )
                            .0 != 0
                            {
                                Network::Testnet
                            } else {
                                Network::Mainnet
                            };
                            snapshot = ScanSnapshot::default();
                            controls.render(&snapshot, network)?;
                        }
                        13 => {
                            if let Some(mut current) = scanner.take() {
                                if current.snapshot().status.is_active() {
                                    current.stop();
                                    snapshot = current.snapshot();
                                    controls.render(&snapshot, network)?;
                                    continue;
                                }
                            }
                            snapshot = ScanSnapshot::default();
                            match Scanner::start(network) {
                                Ok(current) => { snapshot = current.snapshot(); scanner = Some(current); deadline = Instant::now() + Duration::from_secs(30); }
                                Err(error) => snapshot.fail(format!("Cannot start Bluetooth discovery. Check Windows Bluetooth and privacy settings. {error}")),
                            }
                            controls.render(&snapshot, network)?;
                        }
                        _ => {}
                    },
                    LAYOUT => {
                        controls.layout(hwnd)?;
                    }
                    WM_TIMER => {
                        if options.mode == Mode::SmokeTest
                            && opened.elapsed() > Duration::from_secs(3)
                        {
                            DestroyWindow(hwnd)?;
                            continue;
                        }
                        if let Some(current) = &mut scanner {
                            if Instant::now() >= deadline {
                                current.stop();
                            }
                            let next = current.snapshot();
                            if next != snapshot {
                                snapshot = next;
                                controls.render(&snapshot, network)?;
                            }
                            if !snapshot.status.is_active() {
                                scanner = None;
                            }
                        }
                    }
                    _ => {}
                }
            }
            if !IsDialogMessageW(hwnd, &message).as_bool() {
                let _ = TranslateMessage(&message);
                DispatchMessageW(&message);
            }
        }
        drop(scanner);
        Ok(())
    }
}

// Win32 accepts null-valued message parameters; make those explicit at the FFI.
unsafe fn send_message(hwnd: HWND, message: u32, wp: WPARAM, lp: LPARAM) -> LRESULT {
    SendMessageW(hwnd, message, Some(wp), Some(lp))
}
