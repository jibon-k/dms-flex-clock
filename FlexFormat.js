.pragma library

// Flex Clock formatting engine, shared by the bar widget and the settings preview.
//
// Format = Qt date/time format plus:
//   |            new line (\n also works)
//   *text*       bold
//   ~text~       dim
//   !text!       accent color
//   AP ap A a    AM/PM, drawn smaller
// Literal text goes in 'single quotes'; markers inside quotes stay literal.

var AP_OPEN = "";
var AP_CLOSE = "";
var HIDE_OPEN = "";
var HIDE_CLOSE = "";
var BOLD = "";
var DIM = "";
var ACCENT = "";

var STYLE_MARKS = { "*": BOLD, "~": DIM, "!": ACCENT };

function q(s) {
    return "'" + s + "'";
}

function stripQuoted(fmt) {
    return String(fmt).replace(/'[^']*'/g, "");
}

function hasAmPm(fmt) {
    return /[Aa]/.test(stripQuoted(fmt));
}

function hasSeconds(fmt) {
    return /s/.test(stripQuoted(fmt));
}

// Turn our markers into quoted private-use characters Qt passes through.
function encode(fmt) {
    var out = "";
    var inQuote = false;
    for (var i = 0; i < fmt.length; i++) {
        var c = fmt[i];
        if (c === "'") {
            inQuote = !inQuote;
            out += c;
            continue;
        }
        if (inQuote) {
            out += c;
            continue;
        }
        if (c === "A" || c === "a") {
            var two = fmt.substr(i, 2);
            var tok = (two === "AP" || two === "ap") ? two : c;
            out += q(AP_OPEN) + tok + q(AP_CLOSE);
            i += tok.length - 1;
            continue;
        }
        if (STYLE_MARKS[c] !== undefined) {
            out += q(STYLE_MARKS[c]);
            continue;
        }
        out += c;
    }
    return out;
}

function splitLines(fmt) {
    return String(fmt).split(/\||\\n/).filter(function (l) {
        return l.length > 0;
    });
}

// Returns [[{text, small, bold, dim, accent}, ...], ...] — one array per line.
function formatLines(fmt, date, locale) {
    var lines = splitLines(fmt);
    // Qt picks 12/24-hour per format string. If any line has AM/PM, give the
    // others a hidden AM/PM so their hours stay 12-hour, then strip it.
    var twelveHour = hasAmPm(fmt);
    var result = [];
    for (var li = 0; li < lines.length; li++) {
        var line = lines[li];
        var hidden = twelveHour && !hasAmPm(line);
        var lineFmt = encode(line) + (hidden ? q(HIDE_OPEN) + "ap" + q(HIDE_CLOSE) : "");
        var text = date.toLocaleString(locale, lineFmt);
        if (hidden)
            text = text.replace(new RegExp(HIDE_OPEN + "[^" + HIDE_CLOSE + "]*" + HIDE_CLOSE, "g"), "");
        result.push(segment(text));
    }
    return result;
}

function segment(text) {
    var segs = [];
    var st = { "small": false, "bold": false, "dim": false, "accent": false };
    var buf = "";
    function flush() {
        if (buf.length)
            segs.push({ "text": buf, "small": st.small, "bold": st.bold, "dim": st.dim, "accent": st.accent });
        buf = "";
    }
    for (var i = 0; i < text.length; i++) {
        var c = text[i];
        if (c === AP_OPEN || c === AP_CLOSE || c === BOLD || c === DIM || c === ACCENT) {
            flush();
            if (c === AP_OPEN)
                st.small = true;
            else if (c === AP_CLOSE)
                st.small = false;
            else if (c === BOLD)
                st.bold = !st.bold;
            else if (c === DIM)
                st.dim = !st.dim;
            else
                st.accent = !st.accent;
            continue;
        }
        buf += c;
    }
    flush();
    // Let a small AM/PM hug the text before it
    for (var k = 1; k < segs.length; k++) {
        if (segs[k].small && !segs[k - 1].small)
            segs[k - 1].text = segs[k - 1].text.replace(/\s+$/, " ");
    }
    return segs.filter(function (s) {
        return s.text.length > 0;
    });
}

// ─── Presets ───
// value "auto" = follow DMS settings, "custom" = use the custom format field.

var verticalTimePresets = [
    { "label": "Follow DMS settings", "value": "auto" },
    { "label": "01 / 18 / PM", "value": "hh|mm|AP" },
    { "label": "1 / 18 / PM", "value": "h|mm|AP" },
    { "label": "Bold hour  01 / 18 / PM", "value": "*hh*|mm|AP" },
    { "label": "Bold hour, dim minute", "value": "*hh*|~mm~|AP" },
    { "label": "24-hour  13 / 18", "value": "HH|mm" },
    { "label": "Custom…", "value": "custom" }
];

var verticalDatePresets = [
    { "label": "18 / Nov", "value": "d|MMM" },
    { "label": "Bold day  18 / Nov", "value": "*d*|MMM" },
    { "label": "Wed / 18", "value": "ddd|d" },
    { "label": "Wed / 18 / Nov", "value": "ddd|*d*|MMM" },
    { "label": "18 / 11", "value": "dd|MM" },
    { "label": "Custom…", "value": "custom" }
];

var horizontalTimePresets = [
    { "label": "Follow DMS settings", "value": "auto" },
    { "label": "1:18 PM", "value": "h:mm AP" },
    { "label": "01:18 PM", "value": "hh:mm AP" },
    { "label": "Bold hour  1:18 PM", "value": "*h*:mm AP" },
    { "label": "24-hour  13:18", "value": "HH:mm" },
    { "label": "Custom…", "value": "custom" }
];

var horizontalDatePresets = [
    { "label": "Follow DMS settings", "value": "auto" },
    { "label": "Wed 18 Nov", "value": "ddd d MMM" },
    { "label": "18 Nov", "value": "d MMM" },
    { "label": "Wednesday, 18 November", "value": "dddd, d MMMM" },
    { "label": "2026-11-18", "value": "yyyy-MM-dd" },
    { "label": "Custom…", "value": "custom" }
];

// preset unset + custom set keeps formats typed before presets existed.
function resolve(preset, custom, autoFormat) {
    if (!preset)
        return custom || autoFormat;
    if (preset === "auto")
        return autoFormat;
    if (preset === "custom")
        return custom || autoFormat;
    return preset;
}

// ─── Calendar helpers ───

function isoWeek(date) {
    var d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    var day = d.getUTCDay() || 7;
    d.setUTCDate(d.getUTCDate() + 4 - day);
    var yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    return Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
}

function dayOfYear(date) {
    var start = new Date(date.getFullYear(), 0, 1);
    var cur = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    return Math.round((cur - start) / 86400000) + 1;
}

// 42 cells (6 weeks) starting on firstDay (0 = Sunday … 6 = Saturday).
function monthCells(year, month, firstDay) {
    var first = new Date(year, month, 1);
    var offset = (first.getDay() - firstDay + 7) % 7;
    var cells = [];
    for (var i = 0; i < 42; i++) {
        var d = new Date(year, month, 1 - offset + i);
        cells.push({ "day": d.getDate(), "month": d.getMonth(), "year": d.getFullYear(), "inMonth": d.getMonth() === month, "time": d.getTime() });
    }
    return cells;
}

// ─── Preview (settings page) ───

function escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function toHtml(lines, opts) {
    var html = [];
    for (var i = 0; i < lines.length; i++) {
        var parts = [];
        for (var j = 0; j < lines[i].length; j++) {
            var s = lines[i][j];
            var px = s.small ? Math.round(opts.fontPx * opts.ampmScale) : opts.fontPx;
            // Qt rich text has no CSS opacity, so dim uses a pre-faded color
            var color = s.accent ? (s.dim ? opts.dimAccentColor : opts.accentColor) : (s.dim ? opts.dimColor : opts.color);
            var style = "font-size:" + px + "px;color:" + color + ";";
            if (s.bold)
                style += "font-weight:700;";
            parts.push("<span style=\"" + style + "\">" + escapeHtml(s.text).replace(/ /g, "&nbsp;") + "</span>");
        }
        html.push(parts.join(""));
    }
    return html.join(opts.vertical ? "<br/>" : "&nbsp;");
}
