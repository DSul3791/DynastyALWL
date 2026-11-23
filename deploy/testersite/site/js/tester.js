// The tester site's small script (deploy/testersite): login name, latest build, the sortable high-score table, sending forms.
// The front page still works with the report service down: the download box and the links stay, the table says so.
(function () {
  "use strict";
  var me = "";

  function $(sel) { return document.querySelector(sel); }
  function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }
  function getJSON(url) {
    return fetch(url, { credentials: "same-origin", cache: "no-store" }).then(function (r) {
      if (!r.ok) throw new Error(url + " " + r.status);
      return r.json();
    });
  }

  // Login name, top right. Caddy's templates may already have filled it in; otherwise ask the service.
  function showWho() {
    var who = $(".who");
    var filled = who && who.textContent.trim();
    if (filled && filled.indexOf("{") < 0) { me = filled; return Promise.resolve(); }
    if (who) who.textContent = "";
    return getJSON("/api/me").then(function (j) { me = j.user || ""; if (who) who.textContent = me; }).catch(function () {});
  }

  // Latest build: the download box and the forms' Build boxes.
  function showBuild() {
    return getJSON("/latest.json").then(function (j) {
      document.querySelectorAll("[data-build]").forEach(function (e) { e.textContent = "Build " + j.build + (j.size_mb ? " · " + j.size_mb + " MB" : ""); });
      document.querySelectorAll("input[name=build]").forEach(function (e) { if (!e.value) e.value = "Build " + j.build; });
    }).catch(function () {});
  }

  // ---------------------------------------------------------------- high scores
  // Default order (Dave 23 Nov): highest total first; equal totals, everyone at zero included, alphabetical by name.
  var players = [], sortKey = "total", sortDir = -1;

  function drawScores() {
    var tbody = $("#scores tbody");
    if (!tbody) return;
    players.sort(function (a, b) {
      var x = a[sortKey], y = b[sortKey];
      if (sortKey === "user") return sortDir * x.toLowerCase().localeCompare(y.toLowerCase());
      return sortDir * (x - y) || (b.total - a.total) || a.user.toLowerCase().localeCompare(b.user.toLowerCase());
    });
    var ranked = players.slice().sort(function (a, b) { return b.total - a.total; });
    var top = Math.max(1, ranked.length ? ranked[0].total : 1);
    tbody.textContent = "";
    players.forEach(function (p) {
      var tr = el("tr", p.user === me ? "me" : "");
      var rank = ranked.filter(function (q) { return q.total > p.total; }).length + 1;
      tr.appendChild(el("td", "rank", p.total > 0 ? String(rank) : "–"));
      tr.appendChild(el("td", "player", p.user));
      tr.appendChild(el("td", "", String(p.bugs)));
      tr.appendChild(el("td", "", String(p.ideas)));
      tr.appendChild(el("td", "total", String(p.total)));
      var bar = el("td", "bar"), track = el("div", "track");
      track.title = p.user + ": " + p.bugs + " bugs, " + p.ideas + " ideas";
      if (p.bugs) { var b = el("span", "b"); b.style.width = (p.bugs / top * 100) + "%"; track.appendChild(b); }
      if (p.ideas) { var i = el("span", "i"); i.style.width = (p.ideas / top * 100) + "%"; track.appendChild(i); }
      bar.appendChild(track);
      tr.appendChild(bar);
      tbody.appendChild(tr);
    });
    document.querySelectorAll("#scores th[data-key]").forEach(function (th) {
      if (th.dataset.key === sortKey) th.setAttribute("aria-sort", sortDir < 0 ? "descending" : "ascending");
      else th.removeAttribute("aria-sort");
    });
  }

  function showScores() {
    var table = $("#scores");
    if (!table) return;
    document.querySelectorAll("#scores th[data-key] button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var key = btn.parentNode.dataset.key;
        if (key === sortKey) sortDir = -sortDir; else { sortKey = key; sortDir = key === "user" ? 1 : -1; }
        drawScores();
      });
    });
    getJSON("/api/scores").then(function (j) {
      players = j.players || [];
      drawScores();
      var note = $("#scores-note");
      if (note) note.textContent = j.waiting ? j.waiting + " report(s) saved and waiting to reach GitHub." : "";
      var list = $("#recent");
      if (list && j.recent && j.recent.length) {
        list.textContent = "";
        j.recent.forEach(function (r) {
          var li = el("li");
          li.appendChild(el("span", "tag", r.kind === "bug" ? "BUG" : "IDEA"));
          var t = el("span", "t");
          var title = (r.title || "").replace(/^\[(Bug|Idea)\]\s*/, "");
          if (r.issue_url) { var a = el("a", "", title); a.href = r.issue_url; a.target = "_blank"; a.rel = "noopener"; t.appendChild(a); }
          else t.textContent = title + " (on its way)";
          li.appendChild(t);
          li.appendChild(el("span", "by", r.user));
          list.appendChild(li);
        });
        $("#recent-panel").hidden = false;
      }
    }).catch(function () {
      var tbody = $("#scores tbody");
      tbody.textContent = "";
      var tr = el("tr"), td = el("td", "player", "The scores are resting for a moment. Downloads and the links above still work.");
      td.colSpan = 6;
      tr.appendChild(td);
      tbody.appendChild(tr);
    });
  }

  // ---------------------------------------------------------------- the bug and idea forms
  function wireForm() {
    var form = $("form[data-kind]");
    if (!form) return;
    var out = $("#result"), btn = form.querySelector("button[type=submit]");
    form.addEventListener("submit", function (ev) {
      ev.preventDefault();
      out.className = "result"; out.textContent = "";
      btn.disabled = true; btn.textContent = "Sending…";
      fetch("/api/" + form.dataset.kind, {
        method: "POST", body: new FormData(form), credentials: "same-origin", headers: { "X-Dynasty-Form": "1" }
      }).then(function (r) {
        return r.json().catch(function () { return { error: "The site answered " + r.status + "." }; }).then(function (j) { j._ok = r.ok; return j; });
      }).then(function (j) {
        if (!j._ok) throw new Error(j.error || "Something went wrong.");
        out.className = "result ok";
        out.appendChild(el("strong", "", "Thank you, it is in. "));
        if (j.sent && j.issue_url) {
          out.appendChild(document.createTextNode("It is on GitHub as "));
          var a = el("a", "", j.issue_url.replace(/^.*\/issues\//, "issue #")); a.href = j.issue_url; a.target = "_blank"; a.rel = "noopener";
          out.appendChild(a); out.appendChild(document.createTextNode("."));
        } else {
          out.appendChild(document.createTextNode("It is saved and goes to GitHub as soon as GitHub answers; it already counts on the high-score table."));
        }
        out.appendChild(el("br"));
        var again = el("a", "", "Send another"); again.href = location.pathname; out.appendChild(again);
        out.appendChild(document.createTextNode(" · "));
        var home = el("a", "", "Back to the front page"); home.href = "/"; out.appendChild(home);
        form.hidden = true;
      }).catch(function (e) {
        out.className = "result bad";
        out.textContent = (e && e.message && e.message !== "Failed to fetch") ? e.message
          : "The report service did not answer. Your text is still here; try again in a minute.";
      }).then(function () { btn.disabled = false; btn.textContent = btn.dataset.label; });
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    showBuild();
    wireForm();
    showWho().then(showScores);
  });
})();
