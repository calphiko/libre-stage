/**
 * Custom Floating Filter für die Status-Spalte in AG Grid.
 * Rendert ein <select>-Dropdown mit allen vorhandenen Status-Werten.
 * Kommuniziert über einen onFilterChange-Callback nach außen.
 * "retired" ist standardmäßig abgewählt (initialValue = '__no_retired__').
 */
export class StatusFloatingFilter {
  init(params) {
    this.params = params;
    this.values = params.filterParams?.values ?? [];
    this.onFilterChange = params.filterParams?.onFilterChange ?? (() => {});
    this.currentValue = params.filterParams?.initialValue ?? '__no_retired__';

    this.eGui = document.createElement('div');
    this.eGui.style.cssText = 'width:100%; height:100%; display:flex; align-items:center;';

    this.select = document.createElement('select');
    this.select.style.cssText =
      'width:100%; height:28px; border-radius:6px;' +
      'border:1px solid var(--ag-input-border-color, #ccc);' +
      'background:var(--ag-input-background-color, #fff);' +
      'color:var(--ag-foreground-color, #000);' +
      'font-size:13px; padding:0 4px; cursor:pointer;';

    // Option: Alle (inkl. retired)
    const allOption = document.createElement('option');
    allOption.value = '__all__';
    allOption.textContent = 'Alle';
    this.select.appendChild(allOption);

    // Option: Alle außer retired (Standard)
    const noRetiredOption = document.createElement('option');
    noRetiredOption.value = '__no_retired__';
    noRetiredOption.textContent = 'Alle aktiven';
    this.select.appendChild(noRetiredOption);

    // Einzelne Stati
    for (const val of this.values) {
      const opt = document.createElement('option');
      opt.value = val;
      opt.textContent = val;
      this.select.appendChild(opt);
    }

    this.select.value = this.currentValue;

    this.select.addEventListener('change', () => {
      this.currentValue = this.select.value;
      this.onFilterChange(this.currentValue);
    });

    this.eGui.appendChild(this.select);
  }

  // Wird von AG Grid aufgerufen wenn sich der Parent-Filter ändert – hier nicht nötig
  onParentModelChanged() {}

  getGui() {
    return this.eGui;
  }

  destroy() {}
}
