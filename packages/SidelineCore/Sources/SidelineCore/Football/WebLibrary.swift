import Foundation

/// The game library as a static website: an index of games and season
/// records, and one page per game with the score by quarter, recap,
/// leaders and every play, filterable by player and event type, with its
/// clip. Plain HTML, CSS and a few lines of JavaScript, so it opens from a
/// folder and can be put on any static host (GitHub Pages, Netlify, S3…).
///
/// Layout:
///
///     index.html
///     style.css
///     games/<game id>/index.html
///     games/<game id>/game.json          the raw game, for other tools
///     games/<game id>/clips/<event id>.mp4   (written by the app)
public struct WebLibrary: Sendable {
    public struct File: Sendable, Equatable {
        public var path: String
        public var contents: String
    }

    /// A play clip the exporter should cut from a game video.
    public struct Clip: Sendable, Equatable {
        public var gameID: UUID
        public var eventID: UUID
        public var source: VideoRef
        public var path: String
    }

    public var games: [FootballGame]
    public var exportedClips: Set<UUID>
    public var timeZone: TimeZone
    public var generated: Date

    /// `games` in any order (pages list them newest first); `exportedClips`
    /// are the event ids whose clip file exists at `clipPath`.
    public init(games: [FootballGame], exportedClips: Set<UUID> = [], timeZone: TimeZone = .current, generated: Date = Date()) {
        self.games = games.sorted { $0.date > $1.date }
        self.exportedClips = exportedClips
        self.timeZone = timeZone
        self.generated = generated
    }

    public static func gamePath(_ game: UUID) -> String { "games/\(game.uuidString)" }
    public static func clipPath(game: UUID, event: UUID) -> String { "\(gamePath(game))/clips/\(event.uuidString).mp4" }

    /// The first clip of every kept play, across games.
    public static func clipsToExport(_ games: [FootballGame]) -> [Clip] {
        games.flatMap { g in
            g.activeEvents.compactMap { e in
                e.videoRefs.first.map { Clip(gameID: g.id, eventID: e.id, source: $0, path: clipPath(game: g.id, event: e.id)) }
            }
        }
    }

    public func files() -> [File] {
        var out = [File(path: "index.html", contents: indexPage()), File(path: "style.css", contents: Self.css)]
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        for g in games {
            out.append(File(path: "\(Self.gamePath(g.id))/index.html", contents: gamePage(g)))
            if let data = try? enc.encode(g), let json = String(data: data, encoding: .utf8) {
                out.append(File(path: "\(Self.gamePath(g.id))/game.json", contents: json))
            }
        }
        return out
    }

    // MARK: Index

    func indexPage() -> String {
        var body = "<header><h1>Game library</h1><p class=\"muted\">\(games.count) game\(games.count == 1 ? "" : "s") · updated \(esc(format(generated, "MMM d, yyyy")))</p></header>\n"
        let teams = SeasonStats.teamNames(in: games)
        if !teams.isEmpty {
            body += "<section><h2>Season</h2><table class=\"season\"><thead><tr><th>Team</th><th>Record</th><th>PF</th><th>PA</th><th>Games</th></tr></thead><tbody>\n"
            for t in teams {
                let s = SeasonStats(team: t, games: games)
                body += "<tr><td>\(esc(t))</td><td>\(esc(s.record))</td><td>\(s.pointsFor)</td><td>\(s.pointsAgainst)</td><td>\(s.games)</td></tr>\n"
            }
            body += "</tbody></table></section>\n"
        }
        body += "<section><h2>Games</h2>"
        if games.isEmpty { body += "<p class=\"muted\">No games yet.</p>" }
        body += "<ul class=\"games\">\n"
        for g in games {
            let st = g.state
            let plays = g.activeEvents.filter { $0.play != nil }.count
            let clips = g.activeEvents.filter { exportedClips.contains($0.id) }.count
            var meta = [format(g.date, "MMM d, yyyy"), g.isOver ? "Final" : "In progress", "\(plays) play\(plays == 1 ? "" : "s")"]
            if clips > 0 { meta.append("\(clips) clip\(clips == 1 ? "" : "s")") }
            body += "<li><a href=\"\(Self.gamePath(g.id))/index.html\"><span class=\"score\">\(teamLabel(g.away)) \(st.points(.away)) – \(teamLabel(g.home)) \(st.points(.home))</span>"
                + "<span class=\"muted\">\(esc(meta.joined(separator: " · ")))</span></a></li>\n"
        }
        body += "</ul></section>\n"
        return page(title: "Game library", css: "style.css", body: body)
    }

    // MARK: Game

    func gamePage(_ g: FootballGame) -> String {
        let s = GameSummary(game: g)
        let state = g.state
        let status = g.isOver ? "Final" : (state.quarter >= 5 ? "Overtime" : "Q\(state.quarter) · in progress")
        var body = "<nav><a href=\"../../index.html\">← All games</a></nav>\n"
        body += "<header><h1>\(esc(g.away.name)) at \(esc(g.home.name))</h1><p class=\"muted\">\(esc(format(g.date, "EEEE, MMMM d, yyyy")))</p></header>\n"

        // Score by quarter.
        let width = s.byQuarter[.home]?.count ?? 4
        body += "<section class=\"card\"><table class=\"quarters\"><thead><tr><th></th>"
        for q in 0..<width { body += "<th>\(q < 4 ? String(q + 1) : "OT")</th>" }
        body += "<th>T</th></tr></thead><tbody>\n"
        for side in [TeamSide.away, .home] {
            body += "<tr><td>\(teamLabel(g.team(side)))</td>"
            for v in s.byQuarter[side] ?? [] { body += "<td>\(v)</td>" }
            body += "<td class=\"total\">\(s.score[side] ?? 0)</td></tr>\n"
        }
        body += "</tbody></table><p class=\"status\">\(esc(status))</p><p class=\"recap\">\(esc(s.recap))</p></section>\n"

        // Leaders link to that player's plays.
        if !s.leaders.isEmpty {
            body += "<section><h2>Leaders</h2><ul class=\"leaders\">\n"
            for l in s.leaders {
                body += "<li><span class=\"muted\">\(esc(l.category)) · \(esc(g.team(l.player.team).name))</span>"
                    + "<a href=\"#player=\(Self.key(l.player))\">\(esc(l.name))</a> <span>\(esc(l.line))</span></li>\n"
            }
            body += "</ul></section>\n"
        }

        // Plays, with filters.
        let gallery = FootballGallery(game: g)
        let usedTags = PlayTag.allCases.filter { !(gallery.byTag[$0] ?? []).isEmpty }
        body += "<section><h2 id=\"plays-head\">Plays <span id=\"count\" class=\"muted\"></span></h2><div class=\"filters\">"
        body += "<select id=\"player\" aria-label=\"Player\"><option value=\"\">All players</option>"
        for side in [TeamSide.away, .home] {
            let entries = gallery.players.filter { $0.player.team == side }
            guard !entries.isEmpty else { continue }
            body += "<optgroup label=\"\(esc(g.team(side).name))\">"
            for e in entries {
                let roles = e.roles.sorted { ($0.value, $1.key.rawValue) > ($1.value, $0.key.rawValue) }.prefix(2)
                    .map { $0.key.counted($0.value) }.joined(separator: ", ")
                body += "<option value=\"\(Self.key(e.player))\">\(esc(g.displayName(e.player))) (\(esc(roles)))</option>"
            }
            body += "</optgroup>"
        }
        body += "</select><div class=\"chips\" role=\"group\" aria-label=\"Event type\"><button class=\"chip\" data-tag=\"\" aria-pressed=\"true\">All</button>"
        for t in usedTags { body += "<button class=\"chip\" data-tag=\"\(t.rawValue)\" aria-pressed=\"false\">\(esc(t.label))</button>" }
        body += "</div></div>\n<ol id=\"plays\">\n"

        var st = FootballGameState(possession: g.openingKickoff)
        for e in g.activeEvents {
            let q = st.quarter
            FootballGame.apply(e, to: &st)
            guard e.play != nil else {
                body += "<li class=\"note\">\(esc(e.summary))</li>\n"
                continue
            }
            let players = Set(e.involvements.map { Self.key($0.player) }).sorted().joined(separator: " ")
            let tags = e.tags.map(\.rawValue).sorted().joined(separator: " ")
            let qText = q >= 5 ? "OT" : "Q\(q)"
            body += "<li data-players=\"\(players)\" data-tags=\"\(tags)\"><div class=\"play-head\"><span class=\"muted\">\(qText) · \(esc(g.team(e.offense).name)) ball</span>"
            if e.status == .proposed { body += "<span class=\"badge\">unconfirmed</span>" }
            for t in PlayTag.allCases where e.tags.contains(t) { body += "<span class=\"badge tag-\(t.rawValue)\">\(esc(Self.singular(t)))</span>" }
            body += "</div><p class=\"summary\">\(esc(e.summary))</p>"
            let names = Self.uniqued(e.involvements.map { "\(g.displayName($0.player)) (\($0.role.label.lowercased()))" })
            if !names.isEmpty { body += "<p class=\"who muted\">\(esc(names.joined(separator: ", ")))</p>" }
            if let t = e.transcript, !t.isEmpty { body += "<p class=\"said muted\">“\(esc(t))”</p>" }
            if exportedClips.contains(e.id) {
                body += "<video controls playsinline preload=\"metadata\" src=\"clips/\(e.id.uuidString).mp4\"></video>"
            }
            body += "</li>\n"
        }
        body += "</ol></section>\n<script>\(Self.script)</script>\n"
        return page(title: "\(g.away.name) at \(g.home.name)", css: "../../style.css", body: body)
    }

    // MARK: Helpers

    static func singular(_ t: PlayTag) -> String {
        switch t {
        case .touchdown: "Touchdown"
        case .turnover: "Turnover"
        case .bigPlay: "Big play"
        case .sack: "Sack"
        case .kick: "Kick"
        case .penalty: "Penalty"
        }
    }

    static func key(_ p: PlayerKey) -> String { "\(p.team.rawValue)-\(p.jersey)" }

    static func uniqued(_ xs: [String]) -> [String] {
        var seen = Set<String>()
        return xs.filter { seen.insert($0).inserted }
    }

    func teamLabel(_ t: TeamInfo) -> String {
        let dot = t.jerseyColor.flatMap { c in Self.isHexColor(c) ? "<span class=\"dot\" style=\"background:\(c)\"></span>" : nil } ?? ""
        return dot + esc(t.name)
    }

    static func isHexColor(_ s: String) -> Bool {
        s.count == 7 && s.first == "#" && s.dropFirst().allSatisfy(\.isHexDigit)
    }

    func format(_ d: Date, _ pattern: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.timeZone = timeZone
        f.dateFormat = pattern
        return f.string(from: d)
    }

    func page(title: String, css: String, body: String) -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(esc(title))</title>
        <link rel="stylesheet" href="\(css)">
        </head>
        <body>
        <main>
        \(body)</main>
        <footer class="muted">Made with Sideline</footer>
        </body>
        </html>

        """
    }

    static let script = """
    (function () {
      var sel = document.getElementById('player');
      var chips = Array.prototype.slice.call(document.querySelectorAll('.chip'));
      var tag = '';
      function apply() {
        var p = sel.value, n = 0;
        document.querySelectorAll('#plays li').forEach(function (li) {
          var note = li.classList.contains('note');
          var show = note ? (!p && !tag)
            : (!p || li.dataset.players.split(' ').indexOf(p) >= 0) && (!tag || li.dataset.tags.split(' ').indexOf(tag) >= 0);
          li.hidden = !show;
          if (show && !note) n++;
        });
        chips.forEach(function (c) { c.setAttribute('aria-pressed', String(c.dataset.tag === tag)); });
        document.getElementById('count').textContent = n + (n === 1 ? ' play' : ' plays');
        var h = [];
        if (p) h.push('player=' + p);
        if (tag) h.push('tag=' + tag);
        history.replaceState(null, '', h.length ? '#' + h.join('&') : location.pathname);
      }
      function fromHash() {
        var q = {};
        location.hash.replace(/^#/, '').split('&').forEach(function (kv) { var a = kv.split('='); if (a[1]) q[a[0]] = a[1]; });
        sel.value = q.player && sel.querySelector('option[value="' + q.player + '"]') ? q.player : '';
        tag = q.tag && chips.some(function (c) { return c.dataset.tag === q.tag; }) ? q.tag : '';
        apply();
      }
      sel.addEventListener('change', apply);
      chips.forEach(function (c) { c.addEventListener('click', function () { tag = c.dataset.tag; apply(); }); });
      window.addEventListener('hashchange', fromHash);
      document.querySelectorAll('a[href^="#player="]').forEach(function (a) {
        a.addEventListener('click', function (e) {
          e.preventDefault();
          history.replaceState(null, '', a.getAttribute('href'));
          fromHash();
          document.getElementById('plays-head').scrollIntoView({ behavior: 'smooth' });
        });
      });
      fromHash();
    })();
    """

    static let css = """
    :root { --bg: #f4f4f7; --card: #fff; --text: #16161a; --muted: #6b6b76; --line: #e3e3e8; --accent: #0a66d8; --chip: #e8e8ee; }
    @media (prefers-color-scheme: dark) {
      :root { --bg: #0f0f12; --card: #1b1b20; --text: #f0f0f3; --muted: #9a9aa6; --line: #2c2c33; --accent: #5aa2ff; --chip: #2a2a31; }
    }
    * { box-sizing: border-box; }
    body { margin: 0; background: var(--bg); color: var(--text); font: 16px/1.45 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
    main { max-width: 760px; margin: 0 auto; padding: 16px; }
    a { color: var(--accent); text-decoration: none; }
    h1 { font-size: 1.8rem; margin: .4em 0 0; }
    h2 { font-size: 1.15rem; margin: 1.6em 0 .6em; }
    .muted { color: var(--muted); }
    header p { margin: .2em 0 0; }
    nav { margin-top: 8px; }
    .card, .games li a, .leaders, #plays li, table.season { background: var(--card); border-radius: 14px; }
    .card { padding: 16px; margin-top: 16px; }
    table { border-collapse: collapse; }
    table.season { width: 100%; overflow: hidden; }
    table.season th, table.season td { padding: 10px 12px; text-align: left; border-bottom: 1px solid var(--line); }
    table.season tr:last-child td { border-bottom: 0; }
    table.quarters th { font-weight: 500; color: var(--muted); font-size: .85rem; }
    table.quarters td, table.quarters th { padding: 4px 10px; text-align: center; font-variant-numeric: tabular-nums; font-size: 1.15rem; }
    table.quarters td:first-child, table.quarters th:first-child { text-align: left; padding-left: 0; }
    table.quarters .total { font-weight: 700; }
    .status { margin: .6em 0 0; font-weight: 600; }
    .recap { margin: .6em 0 0; }
    .dot { display: inline-block; width: .7em; height: .7em; border-radius: 50%; margin-right: .4em; vertical-align: baseline; border: 1px solid rgba(127,127,127,.4); }
    ul.games, ul.leaders, #plays { list-style: none; margin: 0; padding: 0; }
    .games li { margin-bottom: 10px; }
    .games li a { display: block; padding: 14px 16px; color: inherit; }
    .games .score { display: block; font-weight: 600; font-size: 1.1rem; }
    .leaders { padding: 4px 16px; }
    .leaders li { padding: 10px 0; border-bottom: 1px solid var(--line); }
    .leaders li:last-child { border-bottom: 0; }
    .leaders li .muted { display: block; font-size: .85rem; }
    .filters { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; margin-bottom: 12px; }
    select { font: inherit; padding: 6px 10px; border-radius: 10px; border: 1px solid var(--line); background: var(--card); color: inherit; max-width: 100%; }
    .chips { display: flex; flex-wrap: wrap; gap: 6px; }
    .chip { font: inherit; font-size: .9rem; border: 0; border-radius: 999px; padding: 5px 12px; background: var(--chip); color: inherit; cursor: pointer; }
    .chip[aria-pressed="true"] { background: var(--accent); color: #fff; }
    #plays li { padding: 12px 16px; margin-bottom: 8px; }
    #plays li.note { background: none; padding: 4px 4px 0; color: var(--muted); font-weight: 600; font-size: .9rem; }
    .play-head { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; font-size: .85rem; }
    .badge { font-size: .75rem; padding: 1px 8px; border-radius: 999px; background: var(--chip); }
    .tag-touchdown { background: #1f8a4c; color: #fff; }
    .tag-turnover { background: #c0392b; color: #fff; }
    .summary { margin: .3em 0 0; font-weight: 600; }
    .who, .said { margin: .2em 0 0; font-size: .9rem; }
    video { display: block; width: 100%; max-height: 70vh; margin-top: 10px; border-radius: 10px; background: #000; }
    footer { max-width: 760px; margin: 0 auto; padding: 24px 16px 40px; font-size: .85rem; }
    """
}

/// HTML-escapes text and attribute values.
fileprivate func esc<S: StringProtocol>(_ s: S) -> String {
    var out = ""
    out.reserveCapacity(s.count)
    for c in s {
        switch c {
        case "&": out += "&amp;"
        case "<": out += "&lt;"
        case ">": out += "&gt;"
        case "\"": out += "&quot;"
        case "'": out += "&#39;"
        default: out.append(c)
        }
    }
    return out
}
