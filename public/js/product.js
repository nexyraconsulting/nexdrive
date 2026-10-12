/* NexDrive product page: app links, live trial dates, FAQ. No dependencies.
   The Nexyra top navigation and search are shared files: ../assets/nav/nexyra-nav.js (loaded by the page). */
(function () {
  "use strict";
  var body = document.body;
  var APP = body.getAttribute("data-app-url") || "../index.html";

  /* ---------- App links + live demo ---------- */
  document.querySelectorAll("[data-app]").forEach(function (el) {
    if (el.tagName === "IFRAME") el.src = APP; else el.href = APP;
  });

  /* ---------- Live dates (device clock; refreshed every minute) ---------- */
  var MO = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
  var DW = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
  function fd(d) { return d.getDate() + " " + MO[d.getMonth()]; }
  function addD(d, n) { var x = new Date(d); x.setDate(x.getDate() + n); return x; }
  function addM(d, n) { var x = new Date(d); x.setMonth(x.getMonth() + n); return x; }
  function paintDates() {
    var now = new Date(); now.setHours(12, 0, 0, 0);
    var trialEnd = addD(now, 14), freeEnd = addM(trialEnd, 1);
    var v = {
      today: DW[now.getDay()] + " " + fd(now) + " " + now.getFullYear(),
      reminder: fd(addD(trialEnd, -3)),
      trialEnd: fd(trialEnd),
      refFirstPay: fd(freeEnd) + " " + freeEnd.getFullYear(),
      year: String(now.getFullYear())
    };
    document.querySelectorAll("[data-date]").forEach(function (el) {
      var k = el.getAttribute("data-date"); if (v[k]) el.textContent = v[k];
    });
  }
  paintDates();
  setInterval(paintDates, 60000);
  document.addEventListener("visibilitychange", function () { if (!document.hidden) paintDates(); });

  /* ---------- FAQ (one open at a time) ---------- */
  var faqBtns = Array.prototype.slice.call(document.querySelectorAll(".faq-q"));
  faqBtns.forEach(function (b) {
    b.addEventListener("click", function () {
      var open = b.getAttribute("aria-expanded") === "true";
      faqBtns.forEach(function (o) { o.setAttribute("aria-expanded", "false"); document.getElementById(o.getAttribute("aria-controls")).hidden = true; });
      if (!open) { b.setAttribute("aria-expanded", "true"); document.getElementById(b.getAttribute("aria-controls")).hidden = false; }
    });
  });
})();
