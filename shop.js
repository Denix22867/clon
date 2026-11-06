// Version 1.0.0: purchases are disabled. The game renders the coming-soon screen.
// No payment SDK calls, product catalog, checkout, or entitlement writes.
(() => {
  'use strict';
  window.IskraShop = {
    purchasesEnabled: false,
    init() {}, bindGodot() {}, tick() {}, open() {}, close() {},
    getState() { return {purchasesEnabled: false, initialized: true, busy: false}; }
  };
})();
