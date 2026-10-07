use bitchat_desktop_linux::{
    bluetooth::Scan,
    options::{Mode, Options},
    state::{Network, ScanSnapshot, ScanStatus},
};
use gtk::{gio, glib, prelude::*};
use std::{cell::RefCell, process::ExitCode, rc::Rc, time::Duration};

const APP_ID: &str = "com.bitchat.desktop.linux";

pub fn run(options: Options, runtime: tokio::runtime::Handle) -> ExitCode {
    if gtk::init().is_err() {
        eprintln!("Cannot open a graphical display. Run in a desktop session or use --scan.");
        return ExitCode::FAILURE;
    }
    let app = gtk::Application::builder().application_id(APP_ID).build();
    app.connect_activate(move |app| {
        if let Some(window) = app.active_window() {
            window.present();
            return;
        }
        build_window(app, &options, &runtime);
    });
    // Our arguments are parsed before GTK, including for headless scans.
    let code = app.run_with_args::<&str>(&[]);
    code.into()
}

#[derive(Clone)]
struct DiscoveryView {
    status: gtk::Label,
    devices: gtk::ListBox,
    scan: gtk::Button,
    network: gtk::DropDown,
    count: gtk::Label,
}

impl DiscoveryView {
    fn render(&self, snapshot: &ScanSnapshot) {
        self.scan.set_label(if snapshot.status.is_active() {
            "Stop scan"
        } else {
            "Scan for devices"
        });
        self.scan.set_sensitive(true);
        self.network.set_sensitive(!snapshot.status.is_active());
        let status = match &snapshot.status {
            ScanStatus::Ready => "Ready to discover nearby Bitchat devices.".into(),
            ScanStatus::Starting => "Opening Bluetooth…".into(),
            ScanStatus::Scanning(adapter) => {
                format!("Scanning on {adapter}… Scan stops after 30 seconds.")
            }
            ScanStatus::Finished => "Scan stopped. Results are from the last scan.".into(),
            ScanStatus::Failed(error) => error.clone(),
        };
        self.status.set_text(&status);
        self.count.set_text(&format!(
            "{} devices{}",
            snapshot.devices.len(),
            if snapshot.at_capacity {
                " · display limit reached"
            } else {
                ""
            }
        ));
        while let Some(row) = self.devices.row_at_index(0) {
            self.devices.remove(&row);
        }
        for device in snapshot.devices.values() {
            let row = gtk::Box::new(gtk::Orientation::Horizontal, 16);
            margins(&row, 12);
            let identity = gtk::Box::new(gtk::Orientation::Vertical, 4);
            identity.set_hexpand(true);
            let name = label(&device.name, "heading");
            name.set_ellipsize(gtk::pango::EllipsizeMode::End);
            identity.append(&name);
            identity.append(&label(
                &format!("{} · Unverified device", device.address),
                "dim-label",
            ));
            row.append(&identity);
            row.append(&label(
                &device
                    .rssi
                    .map(|r| format!("{r} dBm"))
                    .unwrap_or_else(|| "No signal data".into()),
                "dim-label",
            ));
            self.devices.append(&row);
        }
    }
}

fn build_window(app: &gtk::Application, options: &Options, runtime: &tokio::runtime::Handle) {
    let window = gtk::ApplicationWindow::builder()
        .application(app)
        .title("BitChat Desktop")
        .default_width(900)
        .default_height(600)
        .build();
    let header = gtk::HeaderBar::new();
    header.set_title_widget(Some(&label(
        "BitChat Desktop · Linux discovery preview",
        "heading",
    )));
    window.set_titlebar(Some(&header));

    let layout = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    let sidebar = gtk::Box::new(gtk::Orientation::Vertical, 16);
    sidebar.set_width_request(180);
    sidebar.add_css_class("background");
    margins(&sidebar, 20);
    sidebar.append(&label("BITCHAT", "title-3"));
    sidebar.append(&label("Nearby devices", "heading"));
    let scope = label(
        "Messaging is coming next.\n\nThis preview discovers devices without joining the mesh.",
        "dim-label",
    );
    scope.set_wrap(true);
    scope.set_max_width_chars(22);
    sidebar.append(&scope);
    layout.append(&sidebar);
    layout.append(&gtk::Separator::new(gtk::Orientation::Vertical));

    let content = gtk::Box::new(gtk::Orientation::Vertical, 16);
    content.set_hexpand(true);
    margins(&content, 28);
    content.append(&label("Nearby devices", "title-1"));
    let intro = label("Find devices advertising the Bitchat Bluetooth service. Device names and addresses are unverified; results can include devices cached by your system.", "dim-label");
    intro.set_wrap(true);
    content.append(&intro);

    let controls = gtk::Box::new(gtk::Orientation::Horizontal, 12);
    controls.append(&label("Network", "heading"));
    let network = gtk::DropDown::from_strings(&["Mainnet", "Testnet"]);
    network.set_selected(if options.network == Network::Testnet {
        1
    } else {
        0
    });
    network.set_tooltip_text(Some(
        "Use Mainnet for normal Bitchat clients. Testnet is the isolated upstream debug network.",
    ));
    controls.append(&network);
    let scan_button = gtk::Button::with_label("Scan for devices");
    scan_button.add_css_class("suggested-action");
    controls.append(&scan_button);
    content.append(&controls);

    let status = label("", "");
    status.set_wrap(true);
    status.set_selectable(true);
    content.append(&status);
    let count = label("0 devices", "heading");
    content.append(&count);
    let devices = gtk::ListBox::new();
    devices.set_selection_mode(gtk::SelectionMode::None);
    devices.add_css_class("boxed-list");
    let empty = gtk::Box::new(gtk::Orientation::Vertical, 10);
    margins(&empty, 28);
    empty.append(&label("No matching devices", "heading"));
    let hint = label(
        "Open Bitchat on a nearby phone, enable Bluetooth, and start a scan.",
        "dim-label",
    );
    hint.set_wrap(true);
    empty.append(&hint);
    devices.set_placeholder(Some(&empty));
    let scroll = gtk::ScrolledWindow::builder()
        .vexpand(true)
        .hexpand(true)
        .hscrollbar_policy(gtk::PolicyType::Never)
        .child(&devices)
        .build();
    content.append(&scroll);
    let privacy = label(
        "Discovery stays in memory. No messages, keys, or device history are saved.",
        "dim-label",
    );
    privacy.set_wrap(true);
    content.append(&privacy);
    layout.append(&content);
    window.set_child(Some(&layout));

    let view = Rc::new(DiscoveryView {
        status,
        devices,
        scan: scan_button.clone(),
        network,
        count,
    });
    view.render(&ScanSnapshot::default());
    let active: Rc<RefCell<Option<Scan>>> = Rc::new(RefCell::new(None));
    view.network.connect_selected_notify({
        let view = Rc::downgrade(&view);
        move |_| {
            // Results from one service must not appear under the other network.
            if let Some(view) = view.upgrade() {
                view.render(&ScanSnapshot::default());
            }
        }
    });
    scan_button.connect_clicked({
        let active = active.clone();
        let options = options.clone();
        let runtime = runtime.clone();
        let view = Rc::downgrade(&view);
        move |_| {
            let Some(view) = view.upgrade() else {
                return;
            };
            if let Some(scan) = active.borrow_mut().as_mut() {
                scan.stop();
                view.scan.set_sensitive(false);
                return;
            }
            let mut options = options.clone();
            options.network = if view.network.selected() == 1 {
                Network::Testnet
            } else {
                Network::Mainnet
            };
            let scan = Scan::start(&runtime, options);
            view.render(&scan.updates.borrow());
            *active.borrow_mut() = Some(scan);
        }
    });
    // GTK is touched only from its main loop. A weak window reference ends
    // polling after teardown; closing drops the scan's cancellation sender.
    glib::timeout_add_local(Duration::from_millis(100), {
        let active = active.clone();
        let weak_window = window.downgrade();
        move || {
            if weak_window.upgrade().is_none() {
                return glib::ControlFlow::Break;
            }
            let mut active = active.borrow_mut();
            if let Some(scan) = active.as_mut() {
                let closed = match scan.updates.has_changed() {
                    Ok(false) => return glib::ControlFlow::Continue,
                    Ok(true) => false,
                    Err(_) => true,
                };
                // Read after observing closure so an update racing with this
                // poll cannot turn a successful final status into a failure.
                let mut snapshot = scan.updates.borrow_and_update().clone();
                if closed && snapshot.status.is_active() {
                    snapshot.fail("Bluetooth worker stopped. Try scanning again.".into());
                }
                view.render(&snapshot);
                if !snapshot.status.is_active() {
                    active.take();
                }
            }
            glib::ControlFlow::Continue
        }
    });
    window.connect_close_request(move |_| {
        active.borrow_mut().take();
        glib::Propagation::Proceed
    });
    let quit = gio::SimpleAction::new("quit", None);
    quit.connect_activate({
        let window = window.downgrade();
        move |_, _| {
            if let Some(window) = window.upgrade() {
                window.close();
            }
        }
    });
    window.add_action(&quit);
    app.set_accels_for_action("win.quit", &["<Primary>q"]);
    window.present();
    if options.mode == Mode::SmokeTest {
        glib::timeout_add_local_once(Duration::from_millis(500), move || {
            assert!(window.is_visible());
            assert!(
                empty.is_mapped(),
                "the empty discovery list must show its placeholder"
            );
            window.close();
        });
    }
}

fn label(text: &str, class: &str) -> gtk::Label {
    let label = gtk::Label::new(Some(text));
    label.set_xalign(0.0);
    if !class.is_empty() {
        label.add_css_class(class);
    }
    label
}

fn margins(widget: &impl IsA<gtk::Widget>, margin: i32) {
    widget.set_margin_top(margin);
    widget.set_margin_bottom(margin);
    widget.set_margin_start(margin);
    widget.set_margin_end(margin);
}
