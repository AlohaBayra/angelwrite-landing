/* ===================================================================
   AngelWrite – zentrale Aktions-Steuerung (Lokal-Tier)
   -------------------------------------------------------------------
   Für eine neue Aktion NUR diese Felder im Block PROMO ändern:
     active   true = Aktion möglich, false = sofort aus (immer 19 €)
     code     Stripe-Promo-Code (muss in Stripe mit gleichem Enddatum existieren)
     start    Startzeitpunkt (ISO, lokale Zeit)
     end      Endzeitpunkt   (ISO, lokale Zeit) – danach automatisch wieder 19 €
     nameDe   Anzeigename Aktion (Deutsch)
     nameEn   Anzeigename Aktion (Englisch)
     buyBase  Stripe-Payment-Link (ohne Parameter)

   Läuft die Aktion ab oder steht active:false, zeigt die Seite den
   Regulärpreis 19 € – ganz ohne weiteren Eingriff.
   =================================================================== */
(function () {
  var PROMO = {
    active:  true,
    code:    'SOMMER26',
    start:   '2026-06-25T00:00:00',
    end:     '2026-07-31T23:59:59',
    nameDe:  'Sommer-Aktion',
    nameEn:  'Summer offer',
    buyBase: 'https://buy.stripe.com/00w4gy5cW26OgqH4CE8bS01'
  };

  function run() {
    var now = new Date();
    var active = PROMO.active
        && now >= new Date(PROMO.start)
        && now <= new Date(PROMO.end);
    if (!active) return; // Regulärpreis 19 € bleibt stehen (HTML-Default)

    var isEn = (document.documentElement.lang || 'de').slice(0, 2) === 'en';
    var end  = new Date(PROMO.end);
    var dateLabel = isEn
        ? end.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })            // "Jul 31"
        : ('0' + end.getDate()).slice(-2) + '.' + ('0' + (end.getMonth() + 1)).slice(-2) + '.'; // "31.07."
    var name       = isEn ? PROMO.nameEn : PROMO.nameDe;
    var regular    = isEn ? '€19'   : '19 €';
    var promoPrice = isEn ? '€0.99' : '0,99 €';
    var numStr     = isEn ? '0.99'       : '0,99';

    var byId = function (id) { return document.getElementById(id); };

    // Badge (nur Aktionsname – kurz, damit nichts abgeschnitten wird)
    var badge = byId('lokal-badge');
    if (badge) {
      badge.textContent = name;
      badge.style.display = '';
    }
    // Aktions-Deadline als eigene Zeile unter dem Preis (wird nie abgeschnitten)
    var deadline = byId('lokal-deadline');
    if (deadline) {
      var fullDate = isEn
          ? end.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })
          : ('0' + end.getDate()).slice(-2) + '.' + ('0' + (end.getMonth() + 1)).slice(-2) + '.' + end.getFullYear();
      deadline.textContent = (isEn ? 'Only until ' : 'Nur noch bis ') + fullDate;
      deadline.style.display = '';
    }
    // Preis: 19 € durchgestrichen + 0,99 €
    var amount = byId('lokal-price');
    if (amount) {
      amount.innerHTML =
        '<span style="font-size:26px;font-weight:600;color:var(--ink-4);text-decoration:line-through;margin-right:10px;">'
        + regular + '</span><span class="cur">€</span>' + numStr;
    }
    // Kauf-Button: Promo-Link + Preis im Text
    var buy = byId('lokal-buy');
    if (buy) buy.href = PROMO.buyBase + '?prefilled_promo_code=' + encodeURIComponent(PROMO.code);
    var buyPrice = byId('lokal-buy-price');
    if (buyPrice) buyPrice.textContent = promoPrice;

    // Preis-Erwähnungen (Trial-Sub, FAQ)
    var prices = document.querySelectorAll('.js-lokal-price');
    for (var i = 0; i < prices.length; i++) prices[i].textContent = promoPrice;

    // Aktions-Hinweis (FAQ)
    var note = isEn
        ? ' — ' + name + ' until ' + dateLabel + ', reg. ' + regular
        : ' — ' + name + ' bis ' + dateLabel + ', statt ' + regular;
    var notes = document.querySelectorAll('.js-promo-note');
    for (var j = 0; j < notes.length; j++) notes[j].textContent = note;
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', run);
  } else {
    run();
  }
})();
