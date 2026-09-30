from playwright.sync_api import sync_playwright

def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={'width': 1280, 'height': 800})
        page.goto('http://localhost:3000/#producao')
        page.wait_for_timeout(500)

        page.evaluate('''() => {
            document.getElementById('view-login').classList.add('hidden');
            document.getElementById('app-shell').classList.remove('hidden');

            document.querySelectorAll('.screen-view').forEach(el => el.classList.add('hidden'));
            document.getElementById('screen-producao').classList.remove('hidden');

            document.getElementById('producao-empty-state').classList.add('hidden');
            document.getElementById('producao-content-container').classList.remove('hidden');

            document.getElementById('prod-op-titulo').textContent = 'OP #OP-2026-TESTE';
            document.getElementById('prod-op-subtitulo').textContent = 'Data: 29/09/2026 • Responsável: João Silva • Situação: em_producao';
            document.getElementById('prod-op-total-planejado').textContent = '200,000 kg';
            document.getElementById('prod-op-total-embutido').textContent = '0,000 kg';

            const container = document.getElementById('lista-bateladas-container');
            container.innerHTML = `
              <div class="bg-white border border-border rounded-xl p-4 shadow-sm flex flex-col justify-between">
                <div>
                  <div class="flex items-center justify-between border-b border-border pb-2 mb-3">
                    <span class="font-bold text-brand-wine text-base">Batelada #1</span>
                    <span class="text-xs bg-gray-100 font-mono px-2 py-0.5 rounded border border-gray-200">Lote: LOTE-OP-2026-TESTE-01</span>
                  </div>

                  <div class="grid grid-cols-2 gap-2 text-xs mb-3">
                    <div>
                      <span class="text-text-muted block">Carne (95%)</span>
                      <span class="font-bold text-brand-ink">142,500 kg</span>
                    </div>
                    <div>
                      <span class="text-text-muted block">Tempero (5%)</span>
                      <span class="font-bold text-brand-ink">7,500 kg</span>
                    </div>
                    <div class="col-span-2 bg-amber-50 p-1.5 rounded border border-amber-200 text-amber-900 font-bold flex justify-between">
                      <span>Peso Total:</span>
                      <span class="text-primary">150,000 kg</span>
                    </div>
                  </div>
                </div>
              </div>

              <div class="bg-white border border-border rounded-xl p-4 shadow-sm flex flex-col justify-between">
                <div>
                  <div class="flex items-center justify-between border-b border-border pb-2 mb-3">
                    <span class="font-bold text-brand-wine text-base">Batelada #2</span>
                    <span class="text-xs bg-gray-100 font-mono px-2 py-0.5 rounded border border-gray-200">Lote: LOTE-OP-2026-TESTE-02</span>
                  </div>

                  <div class="grid grid-cols-2 gap-2 text-xs mb-3">
                    <div>
                      <span class="text-text-muted block">Carne (95%)</span>
                      <span class="font-bold text-brand-ink">47,500 kg</span>
                    </div>
                    <div>
                      <span class="text-text-muted block">Tempero (5%)</span>
                      <span class="font-bold text-brand-ink">2,500 kg</span>
                    </div>
                    <div class="col-span-2 bg-amber-50 p-1.5 rounded border border-amber-200 text-amber-900 font-bold flex justify-between">
                      <span>Peso Total:</span>
                      <span class="text-primary">50,000 kg</span>
                    </div>
                  </div>
                </div>
              </div>
            `;
        }''')

        page.screenshot(path='/home/jules/verification/producao_bateladas.png')
        print('Screenshot gerado com sucesso.')
        browser.close()

if __name__ == '__main__':
    main()
