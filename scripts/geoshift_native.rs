#![no_std]
#![no_main]

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {}
}

#[no_mangle]
pub extern "C" fn rust_eh_personality() {}

extern "C" {
    fn objc_getClass(name: *const u8) -> *mut u8;
    fn sel_registerName(name: *const u8) -> *mut u8;
    fn objc_msgSend(receiver: *mut u8, op: *mut u8, ...) -> *mut u8;
    fn objc_allocateClassPair(superclass: *mut u8, name: *const u8, extra_bytes: usize) -> *mut u8;
    fn objc_registerClassPair(cls: *mut u8);
    fn class_addMethod(cls: *mut u8, name: *mut u8, imp: usize, types: *const u8) -> bool;
    fn class_addIvar(cls: *mut u8, name: *const u8, size: usize, alignment: u8, types: *const u8) -> bool;
    fn object_setInstanceVariable(obj: *mut u8, name: *const u8, value: *mut u8) -> *mut u8;
    fn NSHomeDirectory() -> *mut u8;
    fn UIApplicationMain(
        argc: i32,
        argv: *const *const u8,
        principal_class_name: *const u8,
        delegate_class_name: *const u8,
    ) -> i32;
}

#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct CGRect {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct CLLocationCoordinate2D {
    pub latitude: f64,
    pub longitude: f64,
}

#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct MKCoordinateRegion {
    pub center_lat: f64,
    pub center_lon: f64,
    pub span_lat_delta: f64,
    pub span_lon_delta: f64,
}

struct Waypoint {
    lat: f64,
    lon: f64,
    ele: f64,
    speed_kmh: f64,
    heading: i32,
    name: &'static [u8],
}

static WAYPOINTS: [Waypoint; 16] = [
    Waypoint { lat: 48.858844, lon: 2.294350, ele: 35.0, speed_kmh: 22.5, heading: 65, name: b"Tour Eiffel\0" },
    Waypoint { lat: 48.860120, lon: 2.297500, ele: 34.0, speed_kmh: 24.0, heading: 70, name: b"Pont d'Iena\0" },
    Waypoint { lat: 48.862300, lon: 2.302100, ele: 33.5, speed_kmh: 25.5, heading: 72, name: b"Passerelle Debilly\0" },
    Waypoint { lat: 48.863800, lon: 2.306200, ele: 34.0, speed_kmh: 26.0, heading: 75, name: b"Pont de l'Alma\0" },
    Waypoint { lat: 48.862800, lon: 2.312500, ele: 35.0, speed_kmh: 23.0, heading: 80, name: b"Esplanade Invalides\0" },
    Waypoint { lat: 48.864000, lon: 2.313500, ele: 33.0, speed_kmh: 24.5, heading: 85, name: b"Pont Alexandre III\0" },
    Waypoint { lat: 48.866100, lon: 2.312500, ele: 34.0, speed_kmh: 25.0, heading: 90, name: b"Grand Palais\0" },
    Waypoint { lat: 48.867200, lon: 2.318000, ele: 35.5, speed_kmh: 27.0, heading: 95, name: b"Champs-Elysees\0" },
    Waypoint { lat: 48.865633, lon: 2.321236, ele: 34.0, speed_kmh: 22.0, heading: 100, name: b"Place Concorde\0" },
    Waypoint { lat: 48.863500, lon: 2.327500, ele: 35.0, speed_kmh: 21.0, heading: 105, name: b"Jardin Tuileries\0" },
    Waypoint { lat: 48.861800, lon: 2.332500, ele: 36.0, speed_kmh: 20.0, heading: 110, name: b"Carrousel Louvre\0" },
    Waypoint { lat: 48.860611, lon: 2.337644, ele: 36.0, speed_kmh: 18.5, heading: 115, name: b"Musee du Louvre\0" },
    Waypoint { lat: 48.858300, lon: 2.337500, ele: 34.0, speed_kmh: 22.0, heading: 240, name: b"Pont des Arts\0" },
    Waypoint { lat: 48.857000, lon: 2.341000, ele: 33.0, speed_kmh: 23.5, heading: 250, name: b"Pont Neuf\0" },
    Waypoint { lat: 48.858500, lon: 2.330000, ele: 34.5, speed_kmh: 25.0, heading: 260, name: b"Quai Voltaire\0" },
    Waypoint { lat: 48.862000, lon: 2.310000, ele: 34.0, speed_kmh: 26.5, heading: 265, name: b"Quai d'Orsay\0" },
];

static mut GLOBAL_WINDOW: *mut u8 = core::ptr::null_mut();
static mut GLOBAL_ROOT_VC: *mut u8 = core::ptr::null_mut();
static mut GLOBAL_MAP_VIEW: *mut u8 = core::ptr::null_mut();
static mut GLOBAL_ANNOTATION: *mut u8 = core::ptr::null_mut();
static mut GLOBAL_POS_LABEL: *mut u8 = core::ptr::null_mut();
static mut GLOBAL_SPEED_LABEL: *mut u8 = core::ptr::null_mut();
static mut GLOBAL_ALT_LABEL: *mut u8 = core::ptr::null_mut();
static mut GLOBAL_BADGE_LABEL: *mut u8 = core::ptr::null_mut();
static mut GLOBAL_BTN1: *mut u8 = core::ptr::null_mut();
static mut GLOBAL_BTN2: *mut u8 = core::ptr::null_mut();
static mut GLOBAL_TIMER: *mut u8 = core::ptr::null_mut();
static mut SIMULATION_STEP: usize = 0;
static mut SIMULATION_RUNNING: bool = true;

unsafe fn ns_string(text: &[u8]) -> *mut u8 {
    let cls = objc_getClass(b"NSString\0".as_ptr());
    let sel = sel_registerName(b"stringWithUTF8String:\0".as_ptr());
    type Fn = unsafe extern "C" fn(*mut u8, *mut u8, *const u8) -> *mut u8;
    let f: Fn = core::mem::transmute(objc_msgSend as *const ());
    f(cls, sel, text.as_ptr())
}

unsafe fn ui_color(r: f64, g: f64, b: f64, a: f64) -> *mut u8 {
    let cls = objc_getClass(b"UIColor\0".as_ptr());
    let sel = sel_registerName(b"colorWithRed:green:blue:alpha:\0".as_ptr());
    type Fn = unsafe extern "C" fn(*mut u8, *mut u8, f64, f64, f64, f64) -> *mut u8;
    let f: Fn = core::mem::transmute(objc_msgSend as *const ());
    f(cls, sel, r / 255.0, g / 255.0, b / 255.0, a)
}

unsafe fn ui_font(size: f64, bold: bool) -> *mut u8 {
    let cls = objc_getClass(b"UIFont\0".as_ptr());
    let sel = if bold {
        sel_registerName(b"boldSystemFontOfSize:\0".as_ptr())
    } else {
        sel_registerName(b"systemFontOfSize:\0".as_ptr())
    };
    type Fn = unsafe extern "C" fn(*mut u8, *mut u8, f64) -> *mut u8;
    let f: Fn = core::mem::transmute(objc_msgSend as *const ());
    f(cls, sel, size)
}

unsafe fn create_label(text: &[u8], font_size: f64, bold: bool, color: *mut u8, align: i64) -> *mut u8 {
    let cls = objc_getClass(b"UILabel\0".as_ptr());
    let alloc_sel = sel_registerName(b"alloc\0".as_ptr());
    let init_sel = sel_registerName(b"init\0".as_ptr());
    let raw = objc_msgSend(cls, alloc_sel);
    let label = objc_msgSend(raw, init_sel);

    let str_obj = ns_string(text);
    let set_text = sel_registerName(b"setText:\0".as_ptr());
    objc_msgSend(label, set_text, str_obj);

    let set_color = sel_registerName(b"setTextColor:\0".as_ptr());
    objc_msgSend(label, set_color, color);

    let font = ui_font(font_size, bold);
    let set_font = sel_registerName(b"setFont:\0".as_ptr());
    objc_msgSend(label, set_font, font);

    let set_align = sel_registerName(b"setTextAlignment:\0".as_ptr());
    type AlignFn = unsafe extern "C" fn(*mut u8, *mut u8, i64) -> *mut u8;
    let af: AlignFn = core::mem::transmute(objc_msgSend as *const ());
    af(label, set_align, align);

    let set_lines = sel_registerName(b"setNumberOfLines:\0".as_ptr());
    type LinesFn = unsafe extern "C" fn(*mut u8, *mut u8, i64) -> *mut u8;
    let lf: LinesFn = core::mem::transmute(objc_msgSend as *const ());
    lf(label, set_lines, 0);

    label
}

unsafe fn create_card_view(bg_color: *mut u8, corner_radius: f64) -> *mut u8 {
    let cls = objc_getClass(b"UIView\0".as_ptr());
    let alloc_sel = sel_registerName(b"alloc\0".as_ptr());
    let init_sel = sel_registerName(b"init\0".as_ptr());
    let raw = objc_msgSend(cls, alloc_sel);
    let view = objc_msgSend(raw, init_sel);

    let set_bg = sel_registerName(b"setBackgroundColor:\0".as_ptr());
    objc_msgSend(view, set_bg, bg_color);

    let layer_sel = sel_registerName(b"layer\0".as_ptr());
    let layer = objc_msgSend(view, layer_sel);

    let set_corner = sel_registerName(b"setCornerRadius:\0".as_ptr());
    type CornerFn = unsafe extern "C" fn(*mut u8, *mut u8, f64) -> *mut u8;
    let cf: CornerFn = core::mem::transmute(objc_msgSend as *const ());
    cf(layer, set_corner, corner_radius);

    view
}

fn fmt_int(mut n: i64, buf: &mut [u8]) -> usize {
    if n == 0 {
        buf[0] = b'0';
        return 1;
    }
    let mut neg = false;
    if n < 0 {
        neg = true;
        n = -n;
    }
    let mut temp = [0u8; 20];
    let mut i = 0;
    while n > 0 {
        temp[i] = b'0' + (n % 10) as u8;
        n /= 10;
        i += 1;
    }
    let mut out = 0;
    if neg {
        buf[out] = b'-';
        out += 1;
    }
    while i > 0 {
        i -= 1;
        buf[out] = temp[i];
        out += 1;
    }
    out
}

fn fmt_float4(val: f64, buf: &mut [u8]) -> usize {
    let int_part = val as i64;
    let frac = ((val - (int_part as f64)) * 10000.0) as i64;
    let frac_abs = if frac < 0 { -frac } else { frac };
    let mut len = fmt_int(int_part, buf);
    buf[len] = b'.';
    len += 1;
    let d1 = (frac_abs / 1000) % 10;
    let d2 = (frac_abs / 100) % 10;
    let d3 = (frac_abs / 10) % 10;
    let d4 = frac_abs % 10;
    buf[len] = b'0' + d1 as u8;
    buf[len + 1] = b'0' + d2 as u8;
    buf[len + 2] = b'0' + d3 as u8;
    buf[len + 3] = b'0' + d4 as u8;
    len + 4
}

#[no_mangle]
pub unsafe extern "C" fn on_timer_tick(_app_del: *mut u8, _cmd: *mut u8, _timer: *mut u8) {
    if !SIMULATION_RUNNING {
        return;
    }

    SIMULATION_STEP = (SIMULATION_STEP + 1) % WAYPOINTS.len();
    let wp = &WAYPOINTS[SIMULATION_STEP];
    let coord = CLLocationCoordinate2D { latitude: wp.lat, longitude: wp.lon };

    // 1. Déplacer l'annotation du véhicule sur la carte
    if !GLOBAL_ANNOTATION.is_null() {
        let set_coord_sel = sel_registerName(b"setCoordinate:\0".as_ptr());
        type SetCoordFn = unsafe extern "C" fn(*mut u8, *mut u8, CLLocationCoordinate2D);
        let set_coord: SetCoordFn = core::mem::transmute(objc_msgSend as *const ());
        set_coord(GLOBAL_ANNOTATION, set_coord_sel, coord);

        let set_title = sel_registerName(b"setTitle:\0".as_ptr());
        objc_msgSend(GLOBAL_ANNOTATION, set_title, ns_string(wp.name));
    }

    // 2. Centrer la carte avec animation fluide
    if !GLOBAL_MAP_VIEW.is_null() {
        let set_center_sel = sel_registerName(b"setCenterCoordinate:animated:\0".as_ptr());
        type SetCenterFn = unsafe extern "C" fn(*mut u8, *mut u8, CLLocationCoordinate2D, bool);
        let set_center: SetCenterFn = core::mem::transmute(objc_msgSend as *const ());
        set_center(GLOBAL_MAP_VIEW, set_center_sel, coord, true);
    }

    // 3. Mettre à jour les labels télémétriques
    let set_text_sel = sel_registerName(b"setText:\0".as_ptr());

    if !GLOBAL_POS_LABEL.is_null() {
        let mut buf = [0u8; 80];
        let mut pos = 0;
        let prefix = b"Position : ";
        buf[pos..pos+prefix.len()].copy_from_slice(prefix);
        pos += prefix.len();
        pos += fmt_float4(wp.lat, &mut buf[pos..]);
        let mid = b" N, ";
        buf[pos..pos+mid.len()].copy_from_slice(mid);
        pos += mid.len();
        pos += fmt_float4(wp.lon, &mut buf[pos..]);
        let suf = b" E\0";
        buf[pos..pos+suf.len()].copy_from_slice(suf);
        objc_msgSend(GLOBAL_POS_LABEL, set_text_sel, ns_string(&buf));
    }

    if !GLOBAL_SPEED_LABEL.is_null() {
        let mut buf = [0u8; 80];
        let mut pos = 0;
        let prefix = b"Vitesse  : ";
        buf[pos..pos+prefix.len()].copy_from_slice(prefix);
        pos += prefix.len();
        pos += fmt_int(wp.speed_kmh as i64, &mut buf[pos..]);
        let suf = b" km/h (Velo) | Etape : \0";
        buf[pos..pos+suf.len()].copy_from_slice(suf);
        pos += suf.len() - 1;
        let name_len = wp.name.len();
        buf[pos..pos+name_len].copy_from_slice(wp.name);
        objc_msgSend(GLOBAL_SPEED_LABEL, set_text_sel, ns_string(&buf));
    }

    if !GLOBAL_ALT_LABEL.is_null() {
        let mut buf = [0u8; 80];
        let mut pos = 0;
        let p1 = b"Altitude : ";
        buf[pos..pos+p1.len()].copy_from_slice(p1);
        pos += p1.len();
        pos += fmt_int(wp.ele as i64, &mut buf[pos..]);
        let p2 = b" m  |  Cap : \0";
        buf[pos..pos+p2.len()].copy_from_slice(p2);
        pos += p2.len() - 1;
        pos += fmt_int(wp.heading as i64, &mut buf[pos..]);
        let p3 = b" deg NE\0";
        buf[pos..pos+p3.len()].copy_from_slice(p3);
        objc_msgSend(GLOBAL_ALT_LABEL, set_text_sel, ns_string(&buf));
    }
}

#[no_mangle]
pub unsafe extern "C" fn on_toggle_simulation(_app_del: *mut u8, _cmd: *mut u8, _sender: *mut u8) {
    SIMULATION_RUNNING = !SIMULATION_RUNNING;

    let set_btn_title = sel_registerName(b"setTitle:forState:\0".as_ptr());
    type SetTitleFn = unsafe extern "C" fn(*mut u8, *mut u8, *mut u8, u64) -> *mut u8;
    let stf: SetTitleFn = core::mem::transmute(objc_msgSend as *const ());

    let set_bg_sel = sel_registerName(b"setBackgroundColor:\0".as_ptr());

    if SIMULATION_RUNNING {
        stf(GLOBAL_BTN1, set_btn_title, ns_string(b"Mettre en Pause\0"), 0);
        let accent_blue = ui_color(72.0, 169.0, 255.0, 1.0);
        objc_msgSend(GLOBAL_BTN1, set_bg_sel, accent_blue);
    } else {
        stf(GLOBAL_BTN1, set_btn_title, ns_string(b"Reprendre Trajet\0"), 0);
        let orange_color = ui_color(255.0, 184.0, 77.0, 1.0);
        objc_msgSend(GLOBAL_BTN1, set_bg_sel, orange_color);
    }
}

#[no_mangle]
pub unsafe extern "C" fn on_export_gpx(_app_del: *mut u8, _cmd: *mut u8, _sender: *mut u8) {
    let home = NSHomeDirectory();
    let append_sel = sel_registerName(b"stringByAppendingPathComponent:\0".as_ptr());
    let path = objc_msgSend(home, append_sel, ns_string(b"Documents/GeoShift_Paris.gpx\0"));

    let gpx_xml = b"<?xml version='1.0' encoding='UTF-8'?>\n<gpx version='1.1' creator='GeoShift iOS'>\n  <wpt lat='48.858844' lon='2.294350'><name>Tour Eiffel</name></wpt>\n  <wpt lat='48.865633' lon='2.321236'><name>Concorde</name></wpt>\n  <wpt lat='48.860611' lon='2.337644'><name>Louvre</name></wpt>\n</gpx>\0";
    let gpx_str = ns_string(gpx_xml);
    let write_sel = sel_registerName(b"writeToFile:atomically:encoding:error:\0".as_ptr());
    type WriteFn = unsafe extern "C" fn(*mut u8, *mut u8, *mut u8, bool, u64, *mut u8) -> bool;
    let write_fn: WriteFn = core::mem::transmute(objc_msgSend as *const ());
    write_fn(gpx_str, write_sel, path, true, 4, core::ptr::null_mut::<u8>());

    let url_cls = objc_getClass(b"NSURL\0".as_ptr());
    let file_url_sel = sel_registerName(b"fileURLWithPath:\0".as_ptr());
    let file_url = objc_msgSend(url_cls, file_url_sel, path);

    let arr_cls = objc_getClass(b"NSArray\0".as_ptr());
    let arr_sel = sel_registerName(b"arrayWithObject:\0".as_ptr());
    let items = objc_msgSend(arr_cls, arr_sel, file_url);

    let act_cls = objc_getClass(b"UIActivityViewController\0".as_ptr());
    let alloc_sel = sel_registerName(b"alloc\0".as_ptr());
    let raw_act = objc_msgSend(act_cls, alloc_sel);
    let act_init_sel = sel_registerName(b"initWithActivityItems:applicationActivities:\0".as_ptr());
    let act_vc = objc_msgSend(raw_act, act_init_sel, items, core::ptr::null_mut::<u8>());

    // Compatibilité iPad : configurer popoverPresentationController pour éviter NSGenericException
    let popover_sel = sel_registerName(b"popoverPresentationController\0".as_ptr());
    let popover = objc_msgSend(act_vc, popover_sel);
    if !popover.is_null() && !GLOBAL_ROOT_VC.is_null() {
        let root_view_sel = sel_registerName(b"view\0".as_ptr());
        let root_view = objc_msgSend(GLOBAL_ROOT_VC, root_view_sel);
        let set_source_sel = sel_registerName(b"setSourceView:\0".as_ptr());
        objc_msgSend(popover, set_source_sel, root_view);
    }

    if !GLOBAL_ROOT_VC.is_null() {
        let present_sel = sel_registerName(b"presentViewController:animated:completion:\0".as_ptr());
        type PresentFn = unsafe extern "C" fn(*mut u8, *mut u8, *mut u8, bool, *mut u8);
        let present_fn: PresentFn = core::mem::transmute(objc_msgSend as *const ());
        present_fn(GLOBAL_ROOT_VC, present_sel, act_vc, true, core::ptr::null_mut::<u8>());
    }

    if !GLOBAL_BADGE_LABEL.is_null() {
        let set_text_sel = sel_registerName(b"setText:\0".as_ptr());
        objc_msgSend(GLOBAL_BADGE_LABEL, set_text_sel, ns_string(b"GPX EXPORTE !\0"));
        let accent_blue = ui_color(72.0, 169.0, 255.0, 1.0);
        let set_bg_sel = sel_registerName(b"setBackgroundColor:\0".as_ptr());
        objc_msgSend(GLOBAL_BADGE_LABEL, set_bg_sel, accent_blue);
    }
}

#[no_mangle]
pub unsafe extern "C" fn get_window(_app_delegate: *mut u8, _cmd: *mut u8) -> *mut u8 {
    GLOBAL_WINDOW
}

#[no_mangle]
pub unsafe extern "C" fn set_window(_app_delegate: *mut u8, _cmd: *mut u8, win: *mut u8) {
    GLOBAL_WINDOW = win;
}

#[no_mangle]
pub unsafe extern "C" fn did_finish_launching(
    app_delegate: *mut u8,
    _cmd: *mut u8,
    _application: *mut u8,
    _launch_options: *mut u8,
) -> bool {
    let alloc_sel = sel_registerName(b"alloc\0".as_ptr());
    let init_sel = sel_registerName(b"init\0".as_ptr());
    let add_subview = sel_registerName(b"addSubview:\0".as_ptr());
    let set_frame = sel_registerName(b"setFrame:\0".as_ptr());
    type FrameFn = unsafe extern "C" fn(*mut u8, *mut u8, f64, f64, f64, f64) -> *mut u8;
    let frame_fn: FrameFn = core::mem::transmute(objc_msgSend as *const ());
    type CornerFn = unsafe extern "C" fn(*mut u8, *mut u8, f64) -> *mut u8;
    let cf: CornerFn = core::mem::transmute(objc_msgSend as *const ());

    // 1. Obtenir les dimensions réelles de l'écran (bounds)
    let screen_cls = objc_getClass(b"UIScreen\0".as_ptr());
    let main_screen_sel = sel_registerName(b"mainScreen\0".as_ptr());
    let main_screen = objc_msgSend(screen_cls, main_screen_sel);

    let bounds_sel = sel_registerName(b"bounds\0".as_ptr());
    type BoundsFn = unsafe extern "C" fn(*mut u8, *mut u8) -> CGRect;
    let bounds_fn: BoundsFn = core::mem::transmute(objc_msgSend as *const ());
    let screen_bounds = if !main_screen.is_null() {
        bounds_fn(main_screen, bounds_sel)
    } else {
        CGRect { x: 0.0, y: 0.0, width: 393.0, height: 852.0 }
    };

    let screen_w = if screen_bounds.width > 0.0 { screen_bounds.width } else { 393.0 };
    let screen_h = if screen_bounds.height > 0.0 { screen_bounds.height } else { 852.0 };
    let content_w = screen_w - 32.0;

    // 2. Initialiser UIWindow
    let window_cls = objc_getClass(b"UIWindow\0".as_ptr());
    let raw_win = objc_msgSend(window_cls, alloc_sel);
    let init_frame_sel = sel_registerName(b"initWithFrame:\0".as_ptr());
    type WinInitFn = unsafe extern "C" fn(*mut u8, *mut u8, CGRect) -> *mut u8;
    let win_init_fn: WinInitFn = core::mem::transmute(objc_msgSend as *const ());
    let window = win_init_fn(raw_win, init_frame_sel, CGRect { x: 0.0, y: 0.0, width: screen_w, height: screen_h });

    GLOBAL_WINDOW = window;
    let set_win_sel = sel_registerName(b"setWindow:\0".as_ptr());
    objc_msgSend(app_delegate, set_win_sel, window);

    // Palette GeoShift sombre
    let bg_color = ui_color(9.0, 11.0, 16.0, 1.0);
    let card_bg = ui_color(18.0, 23.0, 34.0, 1.0);
    let accent_blue = ui_color(72.0, 169.0, 255.0, 1.0);
    let accent_emerald = ui_color(53.0, 212.0, 154.0, 1.0);
    let text_white = ui_color(255.0, 255.0, 255.0, 1.0);
    let text_dim = ui_color(160.0, 175.0, 200.0, 1.0);
    let orange_color = ui_color(255.0, 184.0, 77.0, 1.0);

    let set_bg = sel_registerName(b"setBackgroundColor:\0".as_ptr());
    objc_msgSend(window, set_bg, bg_color);

    // 3. Créer RootViewController
    let vc_cls = objc_getClass(b"UIViewController\0".as_ptr());
    let raw_vc = objc_msgSend(vc_cls, alloc_sel);
    let root_vc = objc_msgSend(raw_vc, init_sel);
    GLOBAL_ROOT_VC = root_vc;

    let root_view_sel = sel_registerName(b"view\0".as_ptr());
    let root_view = objc_msgSend(root_vc, root_view_sel);
    objc_msgSend(root_view, set_bg, bg_color);

    // 4. Header Labels
    let top_y = if screen_h > 800.0 { 60.0 } else { 44.0 };
    let title_label = create_label(b"GeoShift\0", 28.0, true, accent_blue, 0);
    frame_fn(title_label, set_frame, 16.0, top_y, 170.0, 34.0);
    objc_msgSend(root_view, add_subview, title_label);

    let badge_label = create_label(b"SIMULATION LOCALE\0", 11.0, true, accent_emerald, 1);
    frame_fn(badge_label, set_frame, screen_w - 176.0, top_y + 6.0, 160.0, 24.0);
    let badge_layer = objc_msgSend(badge_label, sel_registerName(b"layer\0".as_ptr()));
    cf(badge_layer, sel_registerName(b"setCornerRadius:\0".as_ptr()), 8.0);
    type SetBoolFn = unsafe extern "C" fn(*mut u8, *mut u8, bool);
    let set_bool_fn: SetBoolFn = core::mem::transmute(objc_msgSend as *const ());
    let masks_sel = sel_registerName(b"setMasksToBounds:\0".as_ptr());

    let badge_bg = ui_color(18.0, 34.0, 28.0, 1.0);
    objc_msgSend(badge_label, set_bg, badge_bg);
    set_bool_fn(badge_layer, masks_sel, true);
    objc_msgSend(root_view, add_subview, badge_label);
    GLOBAL_BADGE_LABEL = badge_label;

    // 5. Carte MapKit (MKMapView) avec Annotation active
    let map_y = top_y + 44.0;
    let map_cls = objc_getClass(b"MKMapView\0".as_ptr());
    if !map_cls.is_null() {
        let raw_map = objc_msgSend(map_cls, alloc_sel);
        let map_view = objc_msgSend(raw_map, init_sel);
        frame_fn(map_view, set_frame, 16.0, map_y, content_w, 230.0);
        let map_layer = objc_msgSend(map_view, sel_registerName(b"layer\0".as_ptr()));
        cf(map_layer, sel_registerName(b"setCornerRadius:\0".as_ptr()), 16.0);
        set_bool_fn(map_layer, masks_sel, true);

        objc_msgSend(root_view, add_subview, map_view);
        GLOBAL_MAP_VIEW = map_view;

        // Recentrer sur le premier waypoint (Paris Tour Eiffel)
        let first_wp = &WAYPOINTS[0];
        let set_center_sel = sel_registerName(b"setCenterCoordinate:animated:\0".as_ptr());
        type SetCenterFn = unsafe extern "C" fn(*mut u8, *mut u8, CLLocationCoordinate2D, bool);
        let set_center_fn: SetCenterFn = core::mem::transmute(objc_msgSend as *const ());
        set_center_fn(map_view, set_center_sel, CLLocationCoordinate2D { latitude: first_wp.lat, longitude: first_wp.lon }, false);

        // Créer l'annotation du véhicule en simulation
        let anno_cls = objc_getClass(b"MKPointAnnotation\0".as_ptr());
        if !anno_cls.is_null() {
            let raw_anno = objc_msgSend(anno_cls, alloc_sel);
            let annotation = objc_msgSend(raw_anno, init_sel);

            let set_coord_sel = sel_registerName(b"setCoordinate:\0".as_ptr());
            type SetCoordFn = unsafe extern "C" fn(*mut u8, *mut u8, CLLocationCoordinate2D);
            let set_coord_fn: SetCoordFn = core::mem::transmute(objc_msgSend as *const ());
            set_coord_fn(annotation, set_coord_sel, CLLocationCoordinate2D { latitude: first_wp.lat, longitude: first_wp.lon });

            let set_title = sel_registerName(b"setTitle:\0".as_ptr());
            objc_msgSend(annotation, set_title, ns_string(first_wp.name));

            let add_anno_sel = sel_registerName(b"addAnnotation:\0".as_ptr());
            objc_msgSend(map_view, add_anno_sel, annotation);

            GLOBAL_ANNOTATION = annotation;
        }
    }

    // 6. Carte Télémétrie HUD
    let hud_y = map_y + 242.0;
    let hud_card = create_card_view(card_bg, 16.0);
    frame_fn(hud_card, set_frame, 16.0, hud_y, content_w, 195.0);

    let hud_title = create_label(b"T\xC3\x89L\xC3\x89M\xC3\x89TRIE GPS ACTIVE\0", 12.0, true, accent_blue, 0);
    frame_fn(hud_title, set_frame, 16.0, 14.0, content_w - 32.0, 18.0);
    objc_msgSend(hud_card, add_subview, hud_title);

    let pos_label = create_label(b"Position : 48.8588 N, 2.2943 E\0", 15.0, true, text_white, 0);
    frame_fn(pos_label, set_frame, 16.0, 40.0, content_w - 32.0, 22.0);
    objc_msgSend(hud_card, add_subview, pos_label);
    GLOBAL_POS_LABEL = pos_label;

    let speed_label = create_label(b"Vitesse  : 22 km/h (Velo) | Etape : Tour Eiffel\0", 14.0, false, orange_color, 0);
    frame_fn(speed_label, set_frame, 16.0, 70.0, content_w - 32.0, 20.0);
    objc_msgSend(hud_card, add_subview, speed_label);
    GLOBAL_SPEED_LABEL = speed_label;

    let alt_label = create_label(b"Altitude : 35 m  |  Cap : 065 deg NE\0", 14.0, false, text_dim, 0);
    frame_fn(alt_label, set_frame, 16.0, 98.0, content_w - 32.0, 20.0);
    objc_msgSend(hud_card, add_subview, alt_label);
    GLOBAL_ALT_LABEL = alt_label;

    let status_desc = create_label(b"Simulation cin\xC3\xA9matique active (1 Hz)\nParcours interactif Paris Centre\0", 12.0, false, text_dim, 0);
    frame_fn(status_desc, set_frame, 16.0, 128.0, content_w - 32.0, 48.0);
    objc_msgSend(hud_card, add_subview, status_desc);

    objc_msgSend(root_view, add_subview, hud_card);

    // 7. Boutons de Contrôle avec Target-Action réels
    let btn_y = hud_y + 208.0;
    let btn_cls = objc_getClass(b"UIButton\0".as_ptr());
    let sys_btn_sel = sel_registerName(b"buttonWithType:\0".as_ptr());
    type BtnFn = unsafe extern "C" fn(*mut u8, *mut u8, i64) -> *mut u8;
    let bf: BtnFn = core::mem::transmute(objc_msgSend as *const ());
    let set_btn_title = sel_registerName(b"setTitle:forState:\0".as_ptr());
    type SetTitleFn = unsafe extern "C" fn(*mut u8, *mut u8, *mut u8, u64) -> *mut u8;
    let stf: SetTitleFn = core::mem::transmute(objc_msgSend as *const ());

    let add_target_sel = sel_registerName(b"addTarget:action:forControlEvents:\0".as_ptr());
    type AddTargetFn = unsafe extern "C" fn(*mut u8, *mut u8, *mut u8, *mut u8, u64);
    let add_target_fn: AddTargetFn = core::mem::transmute(objc_msgSend as *const ());

    let btn_w = (content_w - 12.0) / 2.0;

    // Bouton 1 : Démarrer / Mettre en Pause
    let btn1 = bf(btn_cls, sys_btn_sel, 1);
    frame_fn(btn1, set_frame, 16.0, btn_y, btn_w, 48.0);
    objc_msgSend(btn1, set_bg, accent_blue);
    stf(btn1, set_btn_title, ns_string(b"Mettre en Pause\0"), 0);
    let btn1_layer = objc_msgSend(btn1, sel_registerName(b"layer\0".as_ptr()));
    cf(btn1_layer, sel_registerName(b"setCornerRadius:\0".as_ptr()), 12.0);
    let toggle_sel = sel_registerName(b"onToggleSimulation:\0".as_ptr());
    add_target_fn(btn1, add_target_sel, app_delegate, toggle_sel, 64);
    objc_msgSend(root_view, add_subview, btn1);
    GLOBAL_BTN1 = btn1;

    // Bouton 2 : Exporter GPX et ouvrir la feuille de partage
    let btn2 = bf(btn_cls, sys_btn_sel, 1);
    frame_fn(btn2, set_frame, 16.0 + btn_w + 12.0, btn_y, btn_w, 48.0);
    let purple_color = ui_color(124.0, 108.0, 255.0, 1.0);
    objc_msgSend(btn2, set_bg, purple_color);
    stf(btn2, set_btn_title, ns_string(b"Partager GPX\0"), 0);
    let btn2_layer = objc_msgSend(btn2, sel_registerName(b"layer\0".as_ptr()));
    cf(btn2_layer, sel_registerName(b"setCornerRadius:\0".as_ptr()), 12.0);
    let export_sel = sel_registerName(b"onExportGPX:\0".as_ptr());
    add_target_fn(btn2, add_target_sel, app_delegate, export_sel, 64);
    objc_msgSend(root_view, add_subview, btn2);
    GLOBAL_BTN2 = btn2;

    // 8. Démarrer le Timer de Simulation GPS (1.0 Hz)
    let timer_cls = objc_getClass(b"NSTimer\0".as_ptr());
    let timer_sel = sel_registerName(b"scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:\0".as_ptr());
    type TimerFn = unsafe extern "C" fn(*mut u8, *mut u8, f64, *mut u8, *mut u8, *mut u8, bool) -> *mut u8;
    let timer_fn: TimerFn = core::mem::transmute(objc_msgSend as *const ());
    let tick_sel = sel_registerName(b"onTimerTick:\0".as_ptr());
    let timer = timer_fn(timer_cls, timer_sel, 1.0, app_delegate, tick_sel, core::ptr::null_mut::<u8>(), true);
    GLOBAL_TIMER = timer;

    // 9. Attacher RootViewController et afficher la fenêtre
    let set_root = sel_registerName(b"setRootViewController:\0".as_ptr());
    objc_msgSend(window, set_root, root_vc);

    let make_key = sel_registerName(b"makeKeyAndVisible\0".as_ptr());
    objc_msgSend(window, make_key);

    true
}

#[no_mangle]
pub extern "C" fn main(argc: i32, argv: *const *const u8) -> i32 {
    unsafe {
        let ns_obj = objc_getClass(b"NSObject\0".as_ptr());
        let app_del_cls = objc_allocateClassPair(ns_obj, b"AppDelegate\0".as_ptr(), 0);

        class_addIvar(
            app_del_cls,
            b"window\0".as_ptr(),
            core::mem::size_of::<*mut u8>(),
            3,
            b"@\0".as_ptr(),
        );

        let launch_sel = sel_registerName(b"application:didFinishLaunchingWithOptions:\0".as_ptr());
        class_addMethod(
            app_del_cls,
            launch_sel,
            did_finish_launching as *const () as usize,
            b"B@:@@\0".as_ptr(),
        );

        let win_sel = sel_registerName(b"window\0".as_ptr());
        class_addMethod(
            app_del_cls,
            win_sel,
            get_window as *const () as usize,
            b"@@:\0".as_ptr(),
        );

        let set_win_sel = sel_registerName(b"setWindow:\0".as_ptr());
        class_addMethod(
            app_del_cls,
            set_win_sel,
            set_window as *const () as usize,
            b"v@:@\0".as_ptr(),
        );

        let tick_sel = sel_registerName(b"onTimerTick:\0".as_ptr());
        class_addMethod(
            app_del_cls,
            tick_sel,
            on_timer_tick as *const () as usize,
            b"v@:@\0".as_ptr(),
        );

        let toggle_sel = sel_registerName(b"onToggleSimulation:\0".as_ptr());
        class_addMethod(
            app_del_cls,
            toggle_sel,
            on_toggle_simulation as *const () as usize,
            b"v@:@\0".as_ptr(),
        );

        let export_sel = sel_registerName(b"onExportGPX:\0".as_ptr());
        class_addMethod(
            app_del_cls,
            export_sel,
            on_export_gpx as *const () as usize,
            b"v@:@\0".as_ptr(),
        );

        objc_registerClassPair(app_del_cls);

        UIApplicationMain(
            argc,
            argv,
            core::ptr::null(),
            b"AppDelegate\0".as_ptr(),
        )
    }
}
