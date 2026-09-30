/* app.js — Lógica da Aplicação Controle de Produção Simples (Quatro Telas) */

// Variáveis Globais
let supabaseClient = null;
let currentUser = null;
let userIsAuthorized = false;
let colaboradoresList = [];
let opList = [];
let selectedProducaoOpId = null;
let opSaboresMap = {}; // ordem_id -> array de sabores

const ADMIN_UID = 'fc952189-34d3-4963-b6c6-f408a249a47b';

// ============================================================================
// 1. INICIALIZAÇÃO, ROTEAMENTO & SESSÃO AUTH
// ============================================================================

document.addEventListener('DOMContentLoaded', async () => {
  initSupabase();
  setupRouter();
  await checkSessionAndPermissions();
});

function initSupabase() {
  const config = window.APP_CONFIG || {};
  const statusBadge = document.getElementById('db-status-badge');

  if (!config.supabaseUrl || !config.supabasePublishableKey || config.supabaseUrl.includes('seu-projeto')) {
    if (statusBadge) {
      statusBadge.className = 'inline-flex items-center gap-1 font-bold text-red-300';
      statusBadge.innerHTML = '<span class="w-2 h-2 rounded-full bg-red-400"></span> Desconectado';
    }
    showGlobalAlert('Configuração do Supabase pendente em config.js');
    return;
  }

  try {
    supabaseClient = supabase.createClient(config.supabaseUrl, config.supabasePublishableKey);
    if (statusBadge) {
      statusBadge.className = 'inline-flex items-center gap-1 font-bold text-emerald-300';
      statusBadge.innerHTML = '<span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span> Conectado';
    }
    hideGlobalAlert();
  } catch (err) {
    console.error('Erro ao inicializar Supabase:', err);
    if (statusBadge) {
      statusBadge.className = 'inline-flex items-center gap-1 font-bold text-red-300';
      statusBadge.innerHTML = '<span class="w-2 h-2 rounded-full bg-red-400"></span> Erro Config';
    }
    showGlobalAlert('Erro ao conectar com o Supabase. Verifique a URL e a Publishable Key em config.js.');
  }
}

function setupRouter() {
  window.addEventListener('hashchange', router);
}

function router() {
  const hash = window.location.hash.replace('#', '') || 'planejamento';
  const validScreens = ['planejamento', 'producao', 'expedicao', 'saldo-loja'];
  const activeScreen = validScreens.includes(hash) ? hash : 'planejamento';

  // Ocultar todas as telas
  document.querySelectorAll('.screen-view').forEach(el => el.classList.add('hidden'));

  // Exibir a tela ativa
  const targetScreen = document.getElementById(`screen-${activeScreen}`);
  if (targetScreen) {
    targetScreen.classList.remove('hidden');
  }

  // Atualizar navegação
  document.querySelectorAll('.nav-link').forEach(link => {
    if (link.getAttribute('data-screen') === activeScreen) {
      link.className = 'nav-link flex items-center gap-3 px-4 py-3 rounded-lg bg-primary-container text-white font-bold shadow-sm transition-all';
    } else {
      link.className = 'nav-link flex items-center gap-3 px-4 py-3 rounded-lg text-white/80 hover:bg-white/10 hover:text-white font-medium transition-all';
    }
  });

  // Atualizar título no header
  const headerTitle = document.getElementById('header-screen-title');
  if (headerTitle) {
    const titles = {
      planejamento: '1. Planejamento de Produção',
      producao: '2. Acompanhamento da Produção',
      expedicao: '3. Expedição e Pedidos Atacado',
      'saldo-loja': '4. Resumo Geral por Sabor — Saldo da Loja'
    };
    headerTitle.textContent = titles[activeScreen];
  }

  // Carregar dados se autenticado e autorizado
  if (userIsAuthorized) {
    if (activeScreen === 'planejamento') loadPlanejamentoData();
    if (activeScreen === 'producao') loadProducaoData();
    if (activeScreen === 'expedicao') loadExpedicaoData();
    if (activeScreen === 'saldo-loja') loadSaldoLojaData();
  }
}

// Check de sessão e autorização RLS (tem_acesso)
async function checkSessionAndPermissions() {
  if (!supabaseClient) return;

  const { data: { session } } = await supabaseClient.auth.getSession();

  if (session && session.user) {
    currentUser = session.user;
    await verifyUserAccess();
  } else {
    currentUser = null;
    userIsAuthorized = false;
    showLoginView();
  }

  // Escutar mudanças de autenticação
  supabaseClient.auth.onAuthStateChange(async (event, session) => {
    if (session && session.user) {
      currentUser = session.user;
      await verifyUserAccess();
    } else {
      currentUser = null;
      userIsAuthorized = false;
      showLoginView();
    }
  });
}

async function verifyUserAccess() {
  if (!supabaseClient || !currentUser) {
    userIsAuthorized = false;
    showLoginView();
    return;
  }

  try {
    const { data, error } = await supabaseClient.rpc('tem_acesso');
    if (error) {
      console.warn('Erro na chamada tem_acesso():', error);
      userIsAuthorized = false;
    } else {
      userIsAuthorized = !!data;
    }
  } catch (e) {
    console.error('Falha na consulta tem_acesso:', e);
    userIsAuthorized = false;
  }

  if (!userIsAuthorized) {
    showLoginView('Atenção: Seu usuário autenticado não possui autorização no banco de dados. Execute o arquivo restaurar_acesso_admin.sql no Supabase.');
  } else {
    showAppShell();
    await loadColaboradores();
    router(); // Recarregar dados da tela atual
  }
}

function showLoginView(errorMsg = '') {
  document.getElementById('view-login').classList.remove('hidden');
  document.getElementById('app-shell').classList.add('hidden');

  const errEl = document.getElementById('login-error-msg');
  if (errorMsg) {
    errEl.textContent = errorMsg;
    errEl.classList.remove('hidden');
  } else {
    errEl.classList.add('hidden');
  }
}

function showAppShell() {
  document.getElementById('view-login').classList.add('hidden');
  document.getElementById('app-shell').classList.remove('hidden');

  const displayEl = document.getElementById('user-display-email');
  if (displayEl && currentUser) {
    if (currentUser.id === ADMIN_UID) {
      displayEl.textContent = 'Admin (' + currentUser.email + ')';
    } else {
      displayEl.textContent = currentUser.email;
    }
  }
}

async function handleLoginSubmit(e) {
  e.preventDefault();
  const email = document.getElementById('login-email').value.trim();
  const password = document.getElementById('login-password').value;
  const errorMsgEl = document.getElementById('login-error-msg');
  const btnSubmit = document.getElementById('btn-login-submit');

  errorMsgEl.classList.add('hidden');
  btnSubmit.disabled = true;
  btnSubmit.innerHTML = 'Entrando...';

  try {
    const { data, error } = await supabaseClient.auth.signInWithPassword({ email, password });
    if (error) throw error;
  } catch (err) {
    errorMsgEl.textContent = err.message || 'Falha na autenticação. Verifique e-mail e senha.';
    errorMsgEl.classList.remove('hidden');
  } finally {
    btnSubmit.disabled = false;
    btnSubmit.innerHTML = '<span>Entrar no Sistema</span>';
  }
}

async function handleLogout() {
  if (supabaseClient) {
    await supabaseClient.auth.signOut();
  }
  currentUser = null;
  userIsAuthorized = false;
  showLoginView();
}

// Helpers para exibição de alertas globais e formatação de erros
function showGlobalAlert(msg) {
  const banner = document.getElementById('global-alert-banner');
  const text = document.getElementById('global-alert-message');
  if (banner && text) {
    text.textContent = msg;
    banner.classList.remove('hidden');
  }
}

function hideGlobalAlert() {
  const banner = document.getElementById('global-alert-banner');
  if (banner) banner.classList.add('hidden');
}

function formatErrorMessage(err) {
  if (!err) return 'Ocorreu um erro desconhecido.';
  const code = err.code || '';
  const message = err.message || String(err);

  if (code === '42501' || message.includes('permission denied') || message.includes('Usuário sem autorização')) {
    return 'Erro de permissão no Supabase (42501): Usuário sem autorização. Execute o arquivo "restaurar_acesso_admin.sql" no SQL Editor do seu projeto Supabase para autorizar este UID.';
  }
  return message;
}

// ============================================================================
// 2. GERENCIAMENTO DE COLABORADORES
// ============================================================================

async function loadColaboradores() {
  if (!supabaseClient || !userIsAuthorized) return;

  try {
    const { data, error } = await supabaseClient
      .from('colaborador')
      .select('*')
      .order('nome');

    if (error) {
      if (error.code === '42501') {
        showGlobalAlert(formatErrorMessage(error));
      }
      throw error;
    }
    colaboradoresList = data || [];
    renderColaboradoresList();
    populateColaboradorDropdowns();
  } catch (err) {
    console.error('Erro ao carregar colaboradores:', err);
  }
}

function renderColaboradoresList() {
  const tbody = document.getElementById('lista-colaboradores-tbody');
  if (!tbody) return;

  if (colaboradoresList.length === 0) {
    tbody.innerHTML = '<tr><td colspan="3" class="p-4 text-center text-text-muted">Nenhum colaborador cadastrado.</td></tr>';
    return;
  }

  tbody.innerHTML = colaboradoresList.map(c => `
    <tr>
      <td class="p-2 font-medium">${escapeHtml(c.nome)}</td>
      <td class="p-2 text-center">
        <span class="px-2 py-0.5 rounded text-xs font-bold ${c.ativo ? 'bg-emerald-100 text-emerald-800' : 'bg-gray-100 text-gray-600'}">
          ${c.ativo ? 'Ativo' : 'Inativo'}
        </span>
      </td>
      <td class="p-2 text-right">
        <button onclick="toggleStatusColaborador('${c.id}', ${!c.ativo})" class="text-xs text-primary hover:underline font-semibold">
          ${c.ativo ? 'Desativar' : 'Ativar'}
        </button>
      </td>
    </tr>
  `).join('');
}

function populateColaboradorDropdowns() {
  const ids = ['op-responsavel', 'batelada-resp-separacao', 'batelada-resp-recebimento'];

  ids.forEach(id => {
    const select = document.getElementById(id);
    if (!select) return;

    const currentVal = select.value;
    select.innerHTML = '<option value="">Selecione...</option>' +
      colaboradoresList.filter(c => c.ativo).map(c => `
        <option value="${escapeHtml(c.nome)}">${escapeHtml(c.nome)}</option>
      `).join('');

    if (currentVal) select.value = currentVal;
  });
}

async function handleSalvarColaborador(e) {
  e.preventDefault();
  const nomeInput = document.getElementById('colaborador-nome');
  const nome = nomeInput.value.trim();

  if (!nome) return;

  try {
    const { error } = await supabaseClient
      .from('colaborador')
      .insert({ nome, ativo: true });

    if (error) throw error;
    nomeInput.value = '';
    await loadColaboradores();
  } catch (err) {
    alert(formatErrorMessage(err));
  }
}

async function toggleStatusColaborador(id, novoStatus) {
  try {
    const { error } = await supabaseClient
      .from('colaborador')
      .update({ ativo: novoStatus })
      .eq('id', id);

    if (error) throw error;
    await loadColaboradores();
  } catch (err) {
    alert(formatErrorMessage(err));
  }
}

function openColaboradoresModal() {
  loadColaboradores();
  openModal('modal-colaboradores');
}

// ============================================================================
// 3. TELA 1 — PLANEJAMENTO
// ============================================================================

async function loadPlanejamentoData() {
  if (!supabaseClient || !userIsAuthorized) return;

  const tbody = document.getElementById('lista-ops-tbody');
  tbody.innerHTML = '<tr><td colspan="7" class="p-8 text-center text-text-muted">Carregando OPs...</td></tr>';

  try {
    const { data: ops, error: errOps } = await supabaseClient
      .from('ordem_producao')
      .select('*')
      .order('criado_em', { ascending: false });

    if (errOps) throw errOps;

    const { data: sabores, error: errSabores } = await supabaseClient
      .from('ordem_sabor')
      .select('*');

    if (errSabores) throw errSabores;

    opList = ops || [];

    opSaboresMap = {};
    (sabores || []).forEach(s => {
      if (!opSaboresMap[s.ordem_id]) opSaboresMap[s.ordem_id] = [];
      opSaboresMap[s.ordem_id].push(s);
    });

    renderPlanejamentoTable();
    updatePlanejamentoStats();
  } catch (err) {
    console.error('Erro ao carregar Planejamento:', err);
    tbody.innerHTML = `<tr><td colspan="7" class="p-8 text-center text-error-text font-semibold">${escapeHtml(formatErrorMessage(err))}</td></tr>`;
  }
}

function renderPlanejamentoTable() {
  const tbody = document.getElementById('lista-ops-tbody');
  if (!tbody) return;

  if (opList.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" class="p-8 text-center text-text-muted">Nenhuma Ordem de Produção cadastrada.</td></tr>';
    return;
  }

  tbody.innerHTML = opList.map(op => {
    const sabores = opSaboresMap[op.id] || [];
    const totalKg = sabores.reduce((acc, s) => acc + (parseFloat(s.planejado_kg) || 0), 0);

    const saboresHtml = sabores.map(s =>
      `<span class="inline-block bg-gray-100 text-gray-800 text-xs px-2 py-0.5 rounded font-medium mr-1 mb-1">
        ${escapeHtml(s.nome)}: <b>${formatKg(s.planejado_kg)} kg</b>
      </span>`
    ).join('');

    const statusBadge = getStatusBadge(op.situacao);

    return `
      <tr class="hover:bg-gray-50">
        <td class="p-3 font-bold text-brand-ink">${escapeHtml(op.numero)}</td>
        <td class="p-3 whitespace-nowrap">${formatDateLocal(op.data)}</td>
        <td class="p-3">${escapeHtml(op.responsavel)}</td>
        <td class="p-3">${statusBadge}</td>
        <td class="p-3">${saboresHtml || '<span class="text-xs text-text-muted">Sem sabores</span>'}</td>
        <td class="p-3 text-right font-bold text-primary">${formatKg(totalKg)} kg</td>
        <td class="p-3 text-center whitespace-nowrap">
          <button onclick="openEditOpModal('${op.id}')" class="px-2 py-1 bg-surface border border-border hover:bg-gray-100 rounded text-xs font-bold text-brand-ink mr-1">
            Editar
          </button>
          ${op.situacao !== 'cancelada' ? `
            <button onclick="cancelarOp('${op.id}')" class="px-2 py-1 bg-error-bg hover:bg-red-100 rounded text-xs font-bold text-error-text">
              Cancelar
            </button>
          ` : ''}
        </td>
      </tr>
    `;
  }).join('');
}

function updatePlanejamentoStats() {
  const opCount = opList.length;
  let totalVol = 0;
  let emProducaoCount = 0;

  opList.forEach(op => {
    if (op.situacao === 'em_producao') emProducaoCount++;
    const sabores = opSaboresMap[op.id] || [];
    sabores.forEach(s => {
      totalVol += (parseFloat(s.planejado_kg) || 0);
    });
  });

  document.getElementById('stat-op-count').textContent = opCount;
  document.getElementById('stat-op-volume').textContent = formatKg(totalVol) + ' kg';
  document.getElementById('stat-op-em-producao').textContent = emProducaoCount;
}

// Modal Nova/Editar OP
function openNovaOpModal() {
  document.getElementById('modal-op-title').textContent = 'Nova Ordem de Produção (OP)';
  document.getElementById('edit-op-id').value = '';
  document.getElementById('form-nova-op').reset();
  document.getElementById('op-situacao-container').classList.add('hidden');
  document.getElementById('op-error-msg').classList.add('hidden');

  document.getElementById('op-data').value = new Date().toISOString().split('T')[0];

  const container = document.getElementById('container-sabores-op');
  container.innerHTML = '';
  adicionarLinhaSaborOp();

  openModal('modal-nova-op');
}

function openEditOpModal(opId) {
  const op = opList.find(o => o.id === opId);
  if (!op) return;

  document.getElementById('modal-op-title').textContent = `Editar OP #${op.numero}`;
  document.getElementById('edit-op-id').value = op.id;
  document.getElementById('op-numero').value = op.numero;
  document.getElementById('op-data').value = op.data;
  document.getElementById('op-responsavel').value = op.responsavel;
  document.getElementById('op-observacoes').value = op.observacoes || '';
  document.getElementById('op-situacao').value = op.situacao;
  document.getElementById('op-situacao-container').classList.remove('hidden');
  document.getElementById('op-error-msg').classList.add('hidden');

  const container = document.getElementById('container-sabores-op');
  container.innerHTML = '';
  const sabores = opSaboresMap[op.id] || [];

  if (sabores.length === 0) {
    adicionarLinhaSaborOp();
  } else {
    sabores.forEach(s => {
      adicionarLinhaSaborOp(s.id, s.nome, s.planejado_kg);
    });
  }

  calcularTotalOp();
  openModal('modal-nova-op');
}

function adicionarLinhaSaborOp(saborId = '', nome = '', planejadoKg = '') {
  const container = document.getElementById('container-sabores-op');
  const div = document.createElement('div');
  div.className = 'flex items-center gap-2 sabor-op-row';
  div.innerHTML = `
    <input type="hidden" class="sabor-id" value="${saborId}" />
    <input type="text" class="sabor-nome flex-1 p-2 border border-border rounded-lg text-sm" placeholder="Nome do Sabor (ex: Tradicional)" required value="${escapeHtml(nome)}" />
    <input type="number" step="0.001" min="0.001" class="sabor-kg w-32 p-2 border border-border rounded-lg text-sm" placeholder="kg" required value="${planejadoKg}" oninput="calcularTotalOp()" />
    <button type="button" onclick="removerLinhaSaborOp(this)" class="p-2 text-red-600 hover:text-red-800 font-bold text-sm">✕</button>
  `;
  container.appendChild(div);
  calcularTotalOp();
}

function removerLinhaSaborOp(btn) {
  const rows = document.querySelectorAll('.sabor-op-row');
  if (rows.length <= 1) {
    alert('A OP deve conter pelo menos um sabor.');
    return;
  }
  btn.closest('.sabor-op-row').remove();
  calcularTotalOp();
}

function calcularTotalOp() {
  let total = 0;
  document.querySelectorAll('.sabor-kg').forEach(input => {
    total += parseFloat(input.value) || 0;
  });
  document.getElementById('op-total-calculado').textContent = formatKg(total) + ' kg';
}

async function handleSalvarOp(e) {
  e.preventDefault();
  const editId = document.getElementById('edit-op-id').value;
  const numero = document.getElementById('op-numero').value.trim();
  const data = document.getElementById('op-data').value;
  const responsavel = document.getElementById('op-responsavel').value;
  const observacoes = document.getElementById('op-observacoes').value.trim();
  const errorMsgEl = document.getElementById('op-error-msg');
  const btnSubmit = document.getElementById('btn-submit-op');

  errorMsgEl.classList.add('hidden');

  const saborRows = document.querySelectorAll('.sabor-op-row');
  const saboresArr = [];
  const nomesVistos = new Set();

  for (const row of saborRows) {
    const saborId = row.querySelector('.sabor-id').value;
    const nome = row.querySelector('.sabor-nome').value.trim();
    const planejadoKg = parseFloat(row.querySelector('.sabor-kg').value);

    if (!nome) {
      showOpError('O nome de todos os sabores é obrigatório.');
      return;
    }
    if (isNaN(planejadoKg) || planejadoKg <= 0) {
      showOpError('A quantidade planejada deve ser maior que zero.');
      return;
    }

    const nomeKey = nome.toLowerCase();
    if (nomesVistos.has(nomeKey)) {
      showOpError(`Sabor duplicado: "${nome}". Cada sabor deve ser único na OP.`);
      return;
    }
    nomesVistos.add(nomeKey);

    saboresArr.push({ id: saborId, nome, planejado_kg: planejadoKg });
  }

  btnSubmit.disabled = true;
  btnSubmit.textContent = 'Salvando...';

  try {
    if (!editId) {
      const payloadSabores = saboresArr.map(s => ({ nome: s.nome, planejado_kg: s.planejado_kg }));
      const { data: opId, error } = await supabaseClient.rpc('fn_criar_ordem_producao', {
        p_numero: numero,
        p_data: data,
        p_responsavel: responsavel,
        p_observacoes: observacoes,
        p_sabores: payloadSabores
      });

      if (error) throw error;
    } else {
      const situacao = document.getElementById('op-situacao').value;

      const { error: errOp } = await supabaseClient
        .from('ordem_producao')
        .update({ numero, data, responsavel, observacoes, situacao })
        .eq('id', editId);

      if (errOp) throw errOp;

      for (const s of saboresArr) {
        if (s.id) {
          const { error: errSabor } = await supabaseClient
            .from('ordem_sabor')
            .update({ nome: s.nome, planejado_kg: s.planejado_kg })
            .eq('id', s.id);
          if (errSabor) throw errSabor;
        } else {
          const { error: errSabor } = await supabaseClient
            .from('ordem_sabor')
            .insert({ ordem_id: editId, nome: s.nome, planejado_kg: s.planejado_kg });
          if (errSabor) throw errSabor;
        }
      }
    }

    closeModal('modal-nova-op');
    await loadPlanejamentoData();
  } catch (err) {
    showOpError(formatErrorMessage(err));
  } finally {
    btnSubmit.disabled = false;
    btnSubmit.textContent = 'Salvar OP';
  }
}

function showOpError(msg) {
  const el = document.getElementById('op-error-msg');
  el.textContent = msg;
  el.classList.remove('hidden');
}

async function cancelarOp(opId) {
  if (!confirm('Deseja realmente cancelar esta Ordem de Produção?')) return;

  try {
    const { error } = await supabaseClient
      .from('ordem_producao')
      .update({ situacao: 'cancelada' })
      .eq('id', opId);

    if (error) throw error;
    await loadPlanejamentoData();
  } catch (err) {
    alert(formatErrorMessage(err));
  }
}

// ============================================================================
// 4. TELA 2 — PRODUÇÃO
// ============================================================================

async function loadProducaoData() {
  if (!supabaseClient || !userIsAuthorized) return;

  try {
    const { data: ops, error } = await supabaseClient
      .from('ordem_producao')
      .select('id, numero, data, responsavel, situacao')
      .neq('situacao', 'cancelada')
      .order('criado_em', { ascending: false });

    if (error) throw error;

    const select = document.getElementById('select-op-producao');
    const currentVal = select.value;

    select.innerHTML = '<option value="">-- Escolha uma OP --</option>' +
      (ops || []).map(o => `
        <option value="${o.id}">OP #${escapeHtml(o.numero)} (${formatDateLocal(o.data)})</option>
      `).join('');

    if (currentVal && (ops || []).some(o => o.id === currentVal)) {
      select.value = currentVal;
      await handleSelectOpProducao(currentVal);
    } else if (ops && ops.length > 0) {
      select.value = ops[0].id;
      await handleSelectOpProducao(ops[0].id);
    } else {
      document.getElementById('producao-empty-state').classList.remove('hidden');
      document.getElementById('producao-content-container').classList.add('hidden');
    }
  } catch (err) {
    console.error('Erro ao carregar dados de Produção:', err);
  }
}

async function handleSelectOpProducao(opId) {
  selectedProducaoOpId = opId;
  const emptyState = document.getElementById('producao-empty-state');
  const container = document.getElementById('producao-content-container');

  if (!opId) {
    emptyState.classList.remove('hidden');
    container.classList.add('hidden');
    return;
  }

  emptyState.classList.add('hidden');
  container.classList.remove('hidden');

  await renderProducaoDetachedOpData(opId);
}

async function renderProducaoDetachedOpData(opId) {
  try {
    const { data: op, error: errOp } = await supabaseClient
      .from('ordem_producao')
      .select('*')
      .eq('id', opId)
      .single();

    if (errOp) throw errOp;

    document.getElementById('prod-op-titulo').textContent = `OP #${op.numero}`;
    document.getElementById('prod-op-subtitulo').textContent =
      `Data: ${formatDateLocal(op.data)} • Responsável: ${escapeHtml(op.responsavel)} • Situação: ${op.situacao}`;

    const { data: bateladas, error: errBat } = await supabaseClient
      .from('batelada')
      .select('*')
      .eq('ordem_id', opId)
      .order('numero');

    if (errBat) throw errBat;

    const { data: sabores, error: errSab } = await supabaseClient
      .from('ordem_sabor')
      .select('*')
      .eq('ordem_id', opId)
      .order('nome');

    if (errSab) throw errSab;

    const totalPlanejado = (sabores || []).reduce((acc, s) => acc + (parseFloat(s.planejado_kg) || 0), 0);
    const totalEmbutido = (sabores || []).reduce((acc, s) => acc + (s.embutido_kg !== null ? (parseFloat(s.embutido_kg) || 0) : 0), 0);

    document.getElementById('prod-op-total-planejado').textContent = formatKg(totalPlanejado) + ' kg';
    document.getElementById('prod-op-total-embutido').textContent = formatKg(totalEmbutido) + ' kg';

    renderBateladasList(bateladas || []);
    renderEmbutimentoList(sabores || []);
  } catch (err) {
    console.error('Erro ao renderizar dados da OP na Produção:', err);
  }
}

function renderBateladasList(bateladas) {
  const container = document.getElementById('lista-bateladas-container');

  if (bateladas.length === 0) {
    container.innerHTML = '<p class="text-text-muted text-sm col-span-2 py-4 text-center">Nenhuma batelada cadastrada para esta OP.</p>';
    return;
  }

  container.innerHTML = bateladas.map(b => {
    const totalKg = (parseFloat(b.carne_kg) || 0) + (parseFloat(b.temperos_kg) || 0);
    const previsaoCura = b.inicio_cura ? new Date(new Date(b.inicio_cura).getTime() + 12 * 60 * 60 * 1000).toLocaleString('pt-BR') : null;

    return `
      <div class="bg-white border border-border rounded-xl p-4 shadow-sm flex flex-col justify-between">
        <div>
          <div class="flex items-center justify-between border-b border-border pb-2 mb-3">
            <span class="font-bold text-brand-wine text-base">Batelada #${b.numero}</span>
            <span class="text-xs bg-gray-100 font-mono px-2 py-0.5 rounded border border-gray-200">Lote: ${escapeHtml(b.lote)}</span>
          </div>

          <div class="grid grid-cols-2 gap-2 text-xs mb-3">
            <div>
              <span class="text-text-muted block">Carne</span>
              <span class="font-bold text-brand-ink">${formatKg(b.carne_kg)} kg</span>
            </div>
            <div>
              <span class="text-text-muted block">Temperos</span>
              <span class="font-bold text-brand-ink">${formatKg(b.temperos_kg)} kg</span>
            </div>
            <div class="col-span-2 bg-amber-50 p-1.5 rounded border border-amber-200 text-amber-900 font-bold flex justify-between">
              <span>Peso Total:</span>
              <span class="text-primary">${formatKg(totalKg)} kg</span>
            </div>
          </div>

          ${b.temperos_descricao ? `
            <div class="text-xs mb-3">
              <span class="text-text-muted block font-semibold mb-0.5">Detalhamento dos Temperos:</span>
              <pre class="bg-gray-50 p-2 rounded text-[11px] font-mono text-gray-700 whitespace-pre-wrap">${escapeHtml(b.temperos_descricao)}</pre>
            </div>
          ` : ''}

          <div class="flex flex-wrap gap-2 text-xs mb-3">
            <span class="px-2 py-1 rounded font-bold ${b.separado ? 'bg-emerald-100 text-emerald-800' : 'bg-gray-100 text-gray-500'}">
              ${b.separado ? '✓ Separado' : 'Separado pendente'}
            </span>
            <span class="px-2 py-1 rounded font-bold ${b.recebido ? 'bg-emerald-100 text-emerald-800' : 'bg-gray-100 text-gray-500'}">
              ${b.recebido ? '✓ Recebido' : 'Recebido pendente'}
            </span>
          </div>

          ${previsaoCura ? `
            <div class="text-[11px] bg-blue-50 text-blue-900 p-2 rounded border border-blue-200 mb-3">
              <span class="font-bold block">Início da Cura: ${new Date(b.inicio_cura).toLocaleString('pt-BR')}</span>
              <span>Previsão de Término (+12h): <b>${previsaoCura}</b></span>
            </div>
          ` : ''}
        </div>

        <div class="pt-2 border-t border-border text-right">
          <button onclick="openEditBateladaModal('${b.id}')" class="px-3 py-1 bg-surface border border-border hover:bg-gray-100 rounded text-xs font-bold text-brand-ink">
            Editar Batelada
          </button>
        </div>
      </div>
    `;
  }).join('');
}

function renderEmbutimentoList(sabores) {
  const container = document.getElementById('lista-embutimento-container');

  if (sabores.length === 0) {
    container.innerHTML = '<p class="text-text-muted text-sm py-4 text-center">Nenhum sabor cadastrado para esta OP.</p>';
    return;
  }

  container.innerHTML = sabores.map(s => {
    const planejado = parseFloat(s.planejado_kg) || 0;
    const isEmbutidoSet = s.embutido_kg !== null && s.embutido_kg !== undefined;
    const embutido = isEmbutidoSet ? parseFloat(s.embutido_kg) : null;

    let diffKgText = '—';
    let diffPctText = '—';
    let diffBadgeClass = 'bg-gray-100 text-gray-600';

    if (isEmbutidoSet) {
      const diffKg = embutido - planejado;
      const diffPct = planejado > 0 ? (diffKg / planejado) * 100 : 0;
      diffKgText = `${diffKg >= 0 ? '+' : ''}${formatKg(diffKg)} kg`;
      diffPctText = `${diffPct >= 0 ? '+' : ''}${diffPct.toFixed(1)}%`;

      if (diffKg > 0) diffBadgeClass = 'bg-amber-100 text-amber-800';
      else if (diffKg < 0) diffBadgeClass = 'bg-blue-100 text-blue-800';
      else diffBadgeClass = 'bg-emerald-100 text-emerald-800';
    }

    return `
      <div class="bg-white border border-border rounded-xl p-4 shadow-sm flex flex-col gap-4">
        <div class="flex flex-wrap items-center justify-between gap-2 border-b border-border pb-3">
          <div>
            <h4 class="font-bold text-brand-ink text-lg">${escapeHtml(s.nome)}</h4>
            <span class="text-xs text-text-muted">Planejado: <b>${formatKg(planejado)} kg</b></span>
          </div>
          <div class="flex items-center gap-2">
            <span class="text-xs uppercase font-bold text-text-muted">Embutido Real:</span>
            <span class="text-lg font-extrabold ${isEmbutidoSet ? 'text-emerald-700' : 'text-amber-600'}">
              ${isEmbutidoSet ? formatKg(embutido) + ' kg' : 'Não informado'}
            </span>
            <span class="px-2 py-0.5 rounded text-xs font-bold ${diffBadgeClass}">
              Dif: ${diffKgText} (${diffPctText})
            </span>
          </div>
        </div>

        <form onsubmit="handleSalvarEmbutimentoSabor(event, '${s.id}')" class="grid grid-cols-1 md:grid-cols-3 gap-4 text-xs">
          <div>
            <label class="block font-bold text-brand-ink mb-1">Insumos Necessários</label>
            <textarea class="sabor-insumos-desc w-full p-2 border border-border rounded-lg" rows="2" placeholder="Tripa, barbante, lacres...">${escapeHtml(s.insumos_descricao || '')}</textarea>
          </div>

          <div class="flex flex-col gap-2">
            <div>
              <label class="block font-bold text-brand-ink mb-1">Resp. Insumos</label>
              <select class="sabor-resp-insumos w-full p-2 border border-border rounded-lg">
                <option value="">Selecione...</option>
                ${colaboradoresList.filter(c => c.ativo).map(c => `
                  <option value="${escapeHtml(c.nome)}" ${c.nome === s.responsavel_insumos ? 'selected' : ''}>${escapeHtml(c.nome)}</option>
                `).join('')}
              </select>
            </div>
            <label class="flex items-center gap-2 font-bold text-brand-ink cursor-pointer mt-1">
              <input type="checkbox" class="sabor-insumos-separados w-4 h-4 text-primary rounded" ${s.insumos_separados ? 'checked' : ''} /> Insumos Separados
            </label>
          </div>

          <div class="flex flex-col gap-2">
            <div class="grid grid-cols-2 gap-2">
              <div>
                <label class="block font-bold text-brand-ink mb-1">Peso Embutido (kg)</label>
                <input type="number" step="0.001" min="0" class="sabor-embutido-kg w-full p-2 border border-border rounded-lg font-bold" placeholder="Ex: 105.000" value="${isEmbutidoSet ? s.embutido_kg : ''}" />
              </div>
              <div>
                <label class="block font-bold text-brand-ink mb-1">Lote</label>
                <input type="text" class="sabor-lote w-full p-2 border border-border rounded-lg" placeholder="Ex: EMB-01" value="${escapeHtml(s.lote || '')}" />
              </div>
            </div>

            <div class="flex items-center justify-between gap-2 mt-1">
              <div class="flex-1">
                <label class="block font-bold text-brand-ink mb-1">Validade</label>
                <input type="date" class="sabor-validade w-full p-1.5 border border-border rounded-lg" value="${s.validade || ''}" />
              </div>
              <button type="submit" class="px-4 py-2 bg-primary hover:bg-brand-wine text-white font-bold rounded-lg shadow shrink-0 self-end">
                Salvar Sabor
              </button>
            </div>
          </div>
        </form>
      </div>
    `;
  }).join('');
}

async function handleSalvarEmbutimentoSabor(e, saborId) {
  e.preventDefault();
  const form = e.target;
  const insumosDesc = form.querySelector('.sabor-insumos-desc').value.trim();
  const respInsumos = form.querySelector('.sabor-resp-insumos').value;
  const insumosSeparados = form.querySelector('.sabor-insumos-separados').checked;
  const embutidoVal = form.querySelector('.sabor-embutido-kg').value;
  const lote = form.querySelector('.sabor-lote').value.trim();
  const validade = form.querySelector('.sabor-validade').value || null;

  const embutidoKg = embutidoVal !== '' ? parseFloat(embutidoVal) : null;

  if (insumosSeparados && !respInsumos) {
    alert('A marcação "Insumos Separados" exige informar o responsável.');
    return;
  }

  try {
    const { error } = await supabaseClient
      .from('ordem_sabor')
      .update({
        insumos_descricao: insumosDesc,
        responsavel_insumos: respInsumos,
        insumos_separados: insumosSeparados,
        embutido_kg: embutidoKg,
        lote: lote,
        validade: validade
      })
      .eq('id', saborId);

    if (error) throw error;
    await renderProducaoDetachedOpData(selectedProducaoOpId);
  } catch (err) {
    alert(formatErrorMessage(err));
  }
}

// Modal Batelada
function openNovaBateladaModal() {
  if (!selectedProducaoOpId) {
    alert('Selecione uma Ordem de Produção primeiro.');
    return;
  }

  document.getElementById('modal-batelada-title').textContent = 'Nova Batelada de Temperos';
  document.getElementById('batelada-id').value = '';
  document.getElementById('form-nova-batelada').reset();
  document.getElementById('batelada-error-msg').classList.add('hidden');
  document.getElementById('batelada-total-display').textContent = '0,000 kg';

  populateColaboradorDropdowns();
  openModal('modal-nova-batelada');
}

async function openEditBateladaModal(bateladaId) {
  try {
    const { data: b, error } = await supabaseClient
      .from('batelada')
      .select('*')
      .eq('id', bateladaId)
      .single();

    if (error) throw error;

    document.getElementById('modal-batelada-title').textContent = `Editar Batelada #${b.numero}`;
    document.getElementById('batelada-id').value = b.id;
    document.getElementById('batelada-numero').value = b.numero;
    document.getElementById('batelada-lote').value = b.lote;
    document.getElementById('batelada-carne-kg').value = b.carne_kg;
    document.getElementById('batelada-temperos-kg').value = b.temperos_kg;
    document.getElementById('batelada-temperos-desc').value = b.temperos_descricao || '';
    document.getElementById('batelada-resp-separacao').value = b.responsavel_separacao || '';
    document.getElementById('batelada-resp-recebimento').value = b.responsavel_recebimento || '';
    document.getElementById('batelada-separado').checked = b.separado;
    document.getElementById('batelada-recebido').checked = b.recebido;
    document.getElementById('batelada-inicio-cura').value = b.inicio_cura ? new Date(b.inicio_cura).toISOString().slice(0, 16) : '';
    document.getElementById('batelada-error-msg').classList.add('hidden');

    calcularTotalBatelada();
    openModal('modal-nova-batelada');
  } catch (err) {
    alert(formatErrorMessage(err));
  }
}

function calcularTotalBatelada() {
  const carne = parseFloat(document.getElementById('batelada-carne-kg').value) || 0;
  const temperos = parseFloat(document.getElementById('batelada-temperos-kg').value) || 0;
  const total = carne + temperos;

  const display = document.getElementById('batelada-total-display');
  display.textContent = formatKg(total) + ' kg';

  if (total > 150) {
    display.className = 'text-sm font-extrabold text-red-600';
  } else {
    display.className = 'text-sm font-extrabold text-primary';
  }
}

async function handleSalvarBatelada(e) {
  e.preventDefault();
  const bateladaId = document.getElementById('batelada-id').value;
  const numero = parseInt(document.getElementById('batelada-numero').value, 10);
  const lote = document.getElementById('batelada-lote').value.trim();
  const carneKg = parseFloat(document.getElementById('batelada-carne-kg').value);
  const temperosKg = parseFloat(document.getElementById('batelada-temperos-kg').value);
  const temperosDesc = document.getElementById('batelada-temperos-desc').value.trim();
  const respSeparacao = document.getElementById('batelada-resp-separacao').value;
  const respRecebimento = document.getElementById('batelada-resp-recebimento').value;
  const separado = document.getElementById('batelada-separado').checked;
  const recebido = document.getElementById('batelada-recebido').checked;
  const inicioCura = document.getElementById('batelada-inicio-cura').value || null;
  const errorMsgEl = document.getElementById('batelada-error-msg');
  const btnSubmit = document.getElementById('btn-submit-batelada');

  errorMsgEl.classList.add('hidden');

  const totalKg = carneKg + temperosKg;
  if (totalKg > 150) {
    showBateladaError(`Capacidade máxima excedida! Total: ${formatKg(totalKg)} kg. O limite é 150,000 kg.`);
    return;
  }

  if (separado && !respSeparacao) {
    showBateladaError('A marcação "Separado" exige selecionar o Responsável pela Separação.');
    return;
  }
  if (recebido && !separado) {
    showBateladaError('A marcação "Recebido" exige que a batelada esteja marcada como "Separado".');
    return;
  }
  if (recebido && !respRecebimento) {
    showBateladaError('A marcação "Recebido" exige selecionar o Responsável pelo Recebimento.');
    return;
  }

  btnSubmit.disabled = true;
  btnSubmit.textContent = 'Salvando...';

  const payload = {
    ordem_id: selectedProducaoOpId,
    numero,
    lote,
    carne_kg: carneKg,
    temperos_kg: temperosKg,
    temperos_descricao: temperosDesc,
    responsavel_separacao: respSeparacao,
    responsavel_recebimento: respRecebimento,
    separado,
    recebido,
    inicio_cura: inicioCura ? new Date(inicioCura).toISOString() : null
  };

  try {
    if (!bateladaId) {
      const { error } = await supabaseClient
        .from('batelada')
        .insert(payload);
      if (error) throw error;
    } else {
      const { error } = await supabaseClient
        .from('batelada')
        .update(payload)
        .eq('id', bateladaId);
      if (error) throw error;
    }

    closeModal('modal-nova-batelada');
    await renderProducaoDetachedOpData(selectedProducaoOpId);
  } catch (err) {
    showBateladaError(formatErrorMessage(err));
  } finally {
    btnSubmit.disabled = false;
    btnSubmit.textContent = 'Salvar Batelada';
  }
}

function showBateladaError(msg) {
  const el = document.getElementById('batelada-error-msg');
  el.textContent = msg;
  el.classList.remove('hidden');
}

// ============================================================================
// 5. TELA 3 — EXPEDIÇÃO
// ============================================================================

async function loadExpedicaoData() {
  if (!supabaseClient || !userIsAuthorized) return;

  try {
    const { data: pedidos, error: errPed } = await supabaseClient
      .from('pedido')
      .select('*, ordem_producao(numero)')
      .order('criado_em', { ascending: false });

    if (errPed) throw errPed;

    const { data: itens, error: errItens } = await supabaseClient
      .from('pedido_item')
      .select('*, ordem_sabor(nome)');

    if (errItens) throw errItens;

    renderPedidosTable(pedidos || [], itens || []);
  } catch (err) {
    console.error('Erro ao carregar dados da Expedição:', err);
  }
}

function renderPedidosTable(pedidos, itens) {
  const tbody = document.getElementById('lista-pedidos-tbody');
  if (!tbody) return;

  if (pedidos.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" class="p-8 text-center text-text-muted">Nenhum pedido de atacado cadastrado.</td></tr>';
    return;
  }

  const itensMap = {};
  itens.forEach(it => {
    if (!itensMap[it.pedido_id]) itensMap[it.pedido_id] = [];
    itensMap[it.pedido_id].push(it);
  });

  tbody.innerHTML = pedidos.map(p => {
    const pItens = itensMap[p.id] || [];
    const opNumero = p.ordem_producao ? p.ordem_producao.numero : '—';

    const itensHtml = pItens.map(it => {
      const saborNome = it.ordem_sabor ? it.ordem_sabor.nome : '—';
      return `<div class="text-xs bg-gray-50 border border-border p-1.5 rounded mb-1">
        <b>${escapeHtml(saborNome)}</b> (${it.conservacao}): Sol: ${formatKg(it.solicitado_kg)}kg | Sep: <b>${formatKg(it.separado_kg)}kg</b>
      </div>`;
    }).join('');

    const statusBadge = getPedidoStatusBadge(p.situacao);

    return `
      <tr class="hover:bg-gray-50">
        <td class="p-3 font-bold text-brand-ink">${escapeHtml(p.numero)}</td>
        <td class="p-3">OP #${escapeHtml(opNumero)}</td>
        <td class="p-3 font-semibold">${escapeHtml(p.cliente)}</td>
        <td class="p-3 whitespace-nowrap">${formatDateLocal(p.data)}</td>
        <td class="p-3">${statusBadge}</td>
        <td class="p-3 max-w-xs">${itensHtml || '—'}</td>
        <td class="p-3 text-center whitespace-nowrap">
          <button onclick="openEditPedidoModal('${p.id}')" class="px-2 py-1 bg-surface border border-border hover:bg-gray-100 rounded text-xs font-bold text-brand-ink mr-1">
            Editar / Separar
          </button>
          ${p.situacao !== 'cancelado' ? `
            <button onclick="cancelarPedido('${p.id}')" class="px-2 py-1 bg-error-bg hover:bg-red-100 rounded text-xs font-bold text-error-text">
              Cancelar
            </button>
          ` : ''}
        </td>
      </tr>
    `;
  }).join('');
}

// Modal Novo/Editar Pedido
async function openNovoPedidoModal() {
  document.getElementById('modal-pedido-title').textContent = 'Novo Pedido de Cliente de Atacado';
  document.getElementById('edit-pedido-id').value = '';
  document.getElementById('form-novo-pedido').reset();
  document.getElementById('pedido-situacao-container').classList.add('hidden');
  document.getElementById('pedido-error-msg').classList.add('hidden');

  document.getElementById('pedido-data').value = new Date().toISOString().split('T')[0];

  const selectOp = document.getElementById('pedido-ordem-id');
  const { data: ops } = await supabaseClient
    .from('ordem_producao')
    .select('id, numero, data')
    .neq('situacao', 'cancelada')
    .order('criado_em', { ascending: false });

  selectOp.innerHTML = '<option value="">Selecione a OP...</option>' +
    (ops || []).map(o => `<option value="${o.id}">OP #${escapeHtml(o.numero)} (${formatDateLocal(o.data)})</option>`).join('');

  document.getElementById('container-itens-pedido').innerHTML = '<p class="text-xs text-text-muted">Selecione uma OP acima para adicionar sabores ao pedido.</p>';

  openModal('modal-novo-pedido');
}

async function carregarSaboresParaPedido(ordemId) {
  const container = document.getElementById('container-itens-pedido');
  if (!ordemId) {
    container.innerHTML = '<p class="text-xs text-text-muted">Selecione uma OP acima para adicionar sabores ao pedido.</p>';
    return;
  }

  const { data: sabores } = await supabaseClient
    .from('ordem_sabor')
    .select('*')
    .eq('ordem_id', ordemId)
    .order('nome');

  opSaboresMap[ordemId] = sabores || [];
  container.innerHTML = '';
  adicionarLinhaItemPedido();
}

function adicionarLinhaItemPedido(itemId = '', ordemSaborId = '', conservacao = 'resfriado', solicitadoKg = '', separadoKg = '0') {
  const ordemId = document.getElementById('pedido-ordem-id').value;
  const sabores = opSaboresMap[ordemId] || [];
  const container = document.getElementById('container-itens-pedido');
  const isEditing = !!document.getElementById('edit-pedido-id').value;

  const div = document.createElement('div');
  div.className = 'p-3 bg-gray-50 border border-border rounded-lg flex flex-col sm:flex-row items-center gap-2 item-pedido-row';
  div.innerHTML = `
    <input type="hidden" class="item-id" value="${itemId}" />
    <select class="item-sabor-id flex-1 p-2 border border-border rounded-lg text-xs" ${isEditing ? 'disabled' : 'required'}>
      <option value="">Selecione o Sabor...</option>
      ${sabores.map(s => `<option value="${s.id}" ${s.id === ordemSaborId ? 'selected' : ''}>${escapeHtml(s.nome)} (Plan: ${formatKg(s.planejado_kg)}kg)</option>`).join('')}
    </select>
    <select class="item-conservacao w-28 p-2 border border-border rounded-lg text-xs" ${isEditing ? 'disabled' : 'required'}>
      <option value="resfriado" ${conservacao === 'resfriado' ? 'selected' : ''}>Resfriado</option>
      <option value="congelado" ${conservacao === 'congelado' ? 'selected' : ''}>Congelado</option>
    </select>
    <div class="flex items-center gap-1">
      <span class="text-[11px] font-bold text-text-muted">Sol:</span>
      <input type="number" step="0.001" min="0.001" class="item-solicitado-kg w-24 p-2 border border-border rounded-lg text-xs font-bold" placeholder="kg" required value="${solicitadoKg}" ${isEditing ? 'readonly' : ''} />
    </div>
    <div class="flex items-center gap-1 ${isEditing ? '' : 'hidden'}">
      <span class="text-[11px] font-bold text-text-muted">Sep:</span>
      <input type="number" step="0.001" min="0" class="item-separado-kg w-24 p-2 border border-border rounded-lg text-xs font-bold text-emerald-700" placeholder="kg" value="${separadoKg}" />
    </div>
    ${!isEditing ? `
      <button type="button" onclick="this.closest('.item-pedido-row').remove()" class="p-2 text-red-600 font-bold text-xs">✕</button>
    ` : ''}
  `;
  container.appendChild(div);
}

async function openEditPedidoModal(pedidoId) {
  try {
    const { data: p, error: errP } = await supabaseClient
      .from('pedido')
      .select('*')
      .eq('id', pedidoId)
      .single();

    if (errP) throw errP;

    const { data: pItens, error: errItens } = await supabaseClient
      .from('pedido_item')
      .select('*')
      .eq('pedido_id', pedidoId);

    if (errItens) throw errItens;

    document.getElementById('modal-pedido-title').textContent = `Editar Pedido #${p.numero}`;
    document.getElementById('edit-pedido-id').value = p.id;
    document.getElementById('pedido-numero').value = p.numero;
    document.getElementById('pedido-cliente').value = p.cliente;
    document.getElementById('pedido-data').value = p.data;
    document.getElementById('pedido-destino').value = p.destino || '';
    document.getElementById('pedido-observacoes').value = p.observacoes || '';
    document.getElementById('pedido-situacao').value = p.situacao;
    document.getElementById('pedido-situacao-container').classList.remove('hidden');
    document.getElementById('pedido-error-msg').classList.add('hidden');

    const selectOp = document.getElementById('pedido-ordem-id');
    const { data: ops } = await supabaseClient
      .from('ordem_producao')
      .select('id, numero, data');

    selectOp.innerHTML = (ops || []).map(o => `<option value="${o.id}" ${o.id === p.ordem_id ? 'selected' : ''}>OP #${escapeHtml(o.numero)} (${formatDateLocal(o.data)})</option>`).join('');
    selectOp.disabled = true;

    const { data: sabores } = await supabaseClient
      .from('ordem_sabor')
      .select('*')
      .eq('ordem_id', p.ordem_id);

    opSaboresMap[p.ordem_id] = sabores || [];

    const container = document.getElementById('container-itens-pedido');
    container.innerHTML = '';
    (pItens || []).forEach(it => {
      adicionarLinhaItemPedido(it.id, it.ordem_sabor_id, it.conservacao, it.solicitado_kg, it.separado_kg);
    });

    openModal('modal-novo-pedido');
  } catch (err) {
    alert(formatErrorMessage(err));
  }
}

async function handleSalvarPedido(e) {
  e.preventDefault();
  const editId = document.getElementById('edit-pedido-id').value;
  const numero = document.getElementById('pedido-numero').value.trim();
  const ordemId = document.getElementById('pedido-ordem-id').value;
  const cliente = document.getElementById('pedido-cliente').value.trim();
  const data = document.getElementById('pedido-data').value;
  const destino = document.getElementById('pedido-destino').value.trim();
  const observacoes = document.getElementById('pedido-observacoes').value.trim();
  const errorMsgEl = document.getElementById('pedido-error-msg');
  const btnSubmit = document.getElementById('btn-submit-pedido');

  errorMsgEl.classList.add('hidden');

  const itemRows = document.querySelectorAll('.item-pedido-row');
  const itensArr = [];

  for (const row of itemRows) {
    const itemId = row.querySelector('.item-id').value;
    const saborId = row.querySelector('.item-sabor-id').value;
    const conservacao = row.querySelector('.item-conservacao').value;
    const solicitadoKg = parseFloat(row.querySelector('.item-solicitado-kg').value);
    const separadoKgInput = row.querySelector('.item-separado-kg');
    const separadoKg = separadoKgInput ? parseFloat(separadoKgInput.value) || 0 : 0;

    if (!saborId) {
      showPedidoError('Selecione o sabor para todos os itens.');
      return;
    }
    if (isNaN(solicitadoKg) || solicitadoKg <= 0) {
      showPedidoError('A quantidade solicitada deve ser maior que zero.');
      return;
    }
    if (separadoKg < 0 || separadoKg > solicitadoKg) {
      showPedidoError(`A quantidade separada (${formatKg(separadoKg)} kg) deve estar entre 0 e a quantidade solicitada (${formatKg(solicitadoKg)} kg).`);
      return;
    }

    itensArr.push({ id: itemId, ordem_sabor_id: saborId, conservacao, solicitado_kg: solicitadoKg, separado_kg: separadoKg });
  }

  if (itensArr.length === 0) {
    showPedidoError('Informe pelo menos um item no pedido.');
    return;
  }

  btnSubmit.disabled = true;
  btnSubmit.textContent = 'Salvando...';

  try {
    if (!editId) {
      const payloadItens = itensArr.map(it => ({
        ordem_sabor_id: it.ordem_sabor_id,
        conservacao: it.conservacao,
        solicitado_kg: it.solicitado_kg
      }));

      const { data: pedId, error } = await supabaseClient.rpc('fn_criar_pedido', {
        p_numero: numero,
        p_ordem_id: ordemId,
        p_cliente: cliente,
        p_data: data,
        p_destino: destino,
        p_observacoes: observacoes,
        p_itens: payloadItens
      });

      if (error) throw error;
    } else {
      const situacao = document.getElementById('pedido-situacao').value;

      const { error: errPed } = await supabaseClient
        .from('pedido')
        .update({ numero, cliente, data, destino, observacoes, situacao })
        .eq('id', editId);

      if (errPed) throw errPed;

      for (const it of itensArr) {
        if (it.id) {
          const { error: errIt } = await supabaseClient
            .from('pedido_item')
            .update({ separado_kg: it.separado_kg })
            .eq('id', it.id);
          if (errIt) throw errIt;
        }
      }
    }

    closeModal('modal-novo-pedido');
    await loadExpedicaoData();
  } catch (err) {
    showPedidoError(formatErrorMessage(err));
  } finally {
    btnSubmit.disabled = false;
    btnSubmit.textContent = 'Salvar Pedido';
  }
}

function showPedidoError(msg) {
  const el = document.getElementById('pedido-error-msg');
  el.textContent = msg;
  el.classList.remove('hidden');
}

async function cancelarPedido(pedidoId) {
  if (!confirm('Deseja realmente cancelar este pedido?')) return;

  try {
    const { error } = await supabaseClient
      .from('pedido')
      .update({ situacao: 'cancelado' })
      .eq('id', pedidoId);

    if (error) throw error;
    await loadExpedicaoData();
  } catch (err) {
    alert(formatErrorMessage(err));
  }
}

// ============================================================================
// 6. TELA 4 — RESUMO GERAL POR SABOR (SALDO DA LOJA)
// ============================================================================

async function loadSaldoLojaData(opIdFiltro = '') {
  if (!supabaseClient || !userIsAuthorized) return;

  const tbody = document.getElementById('saldo-loja-tbody');
  const tfoot = document.getElementById('saldo-loja-tfoot');
  tbody.innerHTML = '<tr><td colspan="5" class="p-8 text-center text-text-muted">Carregando saldo da loja...</td></tr>';
  tfoot.innerHTML = '';

  try {
    // 1. Popular OPs para filtro
    const selectOp = document.getElementById('select-op-saldo-loja');
    const { data: ops } = await supabaseClient
      .from('ordem_producao')
      .select('id, numero, data')
      .neq('situacao', 'cancelada')
      .order('criado_em', { ascending: false });

    const currentFiltro = opIdFiltro || selectOp.value;
    selectOp.innerHTML = '<option value="">-- Todas as OPs Ativas --</option>' +
      (ops || []).map(o => `<option value="${o.id}" ${o.id === currentFiltro ? 'selected' : ''}>OP #${escapeHtml(o.numero)} (${formatDateLocal(o.data)})</option>`).join('');

    // 2. Buscar sabores de acordo com o filtro
    let querySabores = supabaseClient
      .from('ordem_sabor')
      .select('*, ordem_producao(numero, situacao)');

    if (currentFiltro) {
      querySabores = querySabores.eq('ordem_id', currentFiltro);
    }

    const { data: sabores, error: errSabores } = await querySabores;
    if (errSabores) throw errSabores;

    // Filtrar sabores de OPs canceladas se não filtrado por OP específica
    const saboresAtivos = (sabores || []).filter(s => s.ordem_producao && s.ordem_producao.situacao !== 'cancelada');

    // 3. Buscar Pedidos ativos para somar quantidades separadas de atacado
    const { data: pedidos, error: errPed } = await supabaseClient
      .from('pedido')
      .select('id, situacao')
      .neq('situacao', 'cancelado');

    if (errPed) throw errPed;

    const { data: itens, error: errItens } = await supabaseClient
      .from('pedido_item')
      .select('pedido_id, ordem_sabor_id, separado_kg');

    if (errItens) throw errItens;

    // Mapear total separado por ordem_sabor_id (somando resfriado e congelado)
    const pedAtivosIds = new Set((pedidos || []).map(p => p.id));
    const separadoMap = {};

    (itens || []).forEach(it => {
      if (pedAtivosIds.has(it.pedido_id)) {
        separadoMap[it.ordem_sabor_id] = (separadoMap[it.ordem_sabor_id] || 0) + (parseFloat(it.separado_kg) || 0);
      }
    });

    renderSaldoLojaTable(saboresAtivos, separadoMap);
  } catch (err) {
    console.error('Erro ao carregar Saldo da Loja:', err);
    tbody.innerHTML = `<tr><td colspan="5" class="p-8 text-center text-error-text font-semibold">${escapeHtml(formatErrorMessage(err))}</td></tr>`;
  }
}

function renderSaldoLojaTable(sabores, separadoMap) {
  const tbody = document.getElementById('saldo-loja-tbody');
  const tfoot = document.getElementById('saldo-loja-tfoot');

  if (sabores.length === 0) {
    tbody.innerHTML = '<tr><td colspan="5" class="p-8 text-center text-text-muted">Nenhum sabor encontrado para o filtro selecionado.</td></tr>';
    tfoot.innerHTML = '';
    return;
  }

  let totalPlanejado = 0;
  let totalEmbutido = 0;
  let totalSeparado = 0;
  let hasAnyEmbutidoSet = false;

  tbody.innerHTML = sabores.map(s => {
    const opNumero = s.ordem_producao ? s.ordem_producao.numero : '—';
    const planejado = parseFloat(s.planejado_kg) || 0;
    const isEmbutidoSet = s.embutido_kg !== null && s.embutido_kg !== undefined;
    const embutido = isEmbutidoSet ? parseFloat(s.embutido_kg) : null;
    const separado = separadoMap[s.id] || 0;

    totalPlanejado += planejado;
    totalSeparado += separado;

    let embutidoText = 'Não informado';
    let saldoLojaText = 'Não informado';
    let saldoBadgeClass = 'bg-gray-100 text-gray-600 font-semibold';

    if (isEmbutidoSet) {
      hasAnyEmbutidoSet = true;
      totalEmbutido += embutido;
      embutidoText = formatKg(embutido) + ' kg';

      const saldo = embutido - separado;
      saldoLojaText = formatKg(saldo) + ' kg';

      if (saldo < 0) {
        saldoBadgeClass = 'bg-red-100 text-red-800 font-extrabold';
      } else {
        saldoBadgeClass = 'bg-emerald-100 text-emerald-800 font-bold';
      }
    }

    return `
      <tr class="hover:bg-gray-50">
        <td class="p-3 border-r border-border font-medium">
          ${escapeHtml(s.nome)} <span class="text-xs text-text-muted">(OP #${escapeHtml(opNumero)})</span>
        </td>
        <td class="p-3 border-r border-border text-right font-medium">${formatKg(planejado)} kg</td>
        <td class="p-3 border-r border-border text-right font-bold ${isEmbutidoSet ? 'text-emerald-700' : 'text-amber-600'}">
          ${embutidoText}
        </td>
        <td class="p-3 border-r border-border text-right font-medium">${formatKg(separado)} kg</td>
        <td class="p-3 text-right">
          <span class="px-2.5 py-1 rounded text-xs ${saldoBadgeClass}">
            ${saldoLojaText}
          </span>
        </td>
      </tr>
    `;
  }).join('');

  // Totais do Footer
  const totalSaldoLojaText = hasAnyEmbutidoSet ? formatKg(totalEmbutido - totalSeparado) + ' kg' : 'Não informado';
  const totalSaldoClass = (hasAnyEmbutidoSet && (totalEmbutido - totalSeparado) < 0) ? 'text-red-700 font-extrabold' : 'text-emerald-700 font-extrabold';

  tfoot.innerHTML = `
    <tr>
      <td class="p-3 border-r border-border">TOTAL GERAL</td>
      <td class="p-3 border-r border-border text-right text-primary">${formatKg(totalPlanejado)} kg</td>
      <td class="p-3 border-r border-border text-right text-emerald-700">${hasAnyEmbutidoSet ? formatKg(totalEmbutido) + ' kg' : 'Não informado'}</td>
      <td class="p-3 border-r border-border text-right">${formatKg(totalSeparado)} kg</td>
      <td class="p-3 text-right ${totalSaldoClass}">${totalSaldoLojaText}</td>
    </tr>
  `;
}

// ============================================================================
// UTILITÁRIOS E HELPERS
// ============================================================================

function openModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) modal.classList.remove('hidden');
}

function closeModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) modal.classList.add('hidden');

  const selectOp = document.getElementById('pedido-ordem-id');
  if (selectOp) selectOp.disabled = false;
}

function toggleSection(sectionId) {
  const sec = document.getElementById(sectionId);
  if (sec) sec.classList.toggle('hidden');
}

function formatKg(val) {
  const num = parseFloat(val);
  if (isNaN(num)) return '0,000';
  return num.toLocaleString('pt-BR', { minimumFractionDigits: 3, maximumFractionDigits: 3 });
}

function formatDateLocal(dateStr) {
  if (!dateStr) return '—';
  const parts = dateStr.split('-');
  if (parts.length === 3) return `${parts[2]}/${parts[1]}/${parts[0]}`;
  return dateStr;
}

function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function getStatusBadge(situacao) {
  const badges = {
    rascunho: '<span class="px-2 py-0.5 rounded text-xs font-bold bg-gray-100 text-gray-700">Rascunho</span>',
    em_producao: '<span class="px-2 py-0.5 rounded text-xs font-bold bg-amber-100 text-amber-800">Em Produção</span>',
    concluida: '<span class="px-2 py-0.5 rounded text-xs font-bold bg-emerald-100 text-emerald-800">Concluída</span>',
    cancelada: '<span class="px-2 py-0.5 rounded text-xs font-bold bg-red-100 text-red-800">Cancelada</span>'
  };
  return badges[situacao] || `<span class="px-2 py-0.5 rounded text-xs font-bold bg-gray-100">${escapeHtml(situacao)}</span>`;
}

function getPedidoStatusBadge(situacao) {
  const badges = {
    rascunho: '<span class="px-2 py-0.5 rounded text-xs font-bold bg-gray-100 text-gray-700">Rascunho</span>',
    separado: '<span class="px-2 py-0.5 rounded text-xs font-bold bg-blue-100 text-blue-800">Separado</span>',
    expedido: '<span class="px-2 py-0.5 rounded text-xs font-bold bg-emerald-100 text-emerald-800">Expedido</span>',
    cancelado: '<span class="px-2 py-0.5 rounded text-xs font-bold bg-red-100 text-red-800">Cancelado</span>'
  };
  return badges[situacao] || `<span class="px-2 py-0.5 rounded text-xs font-bold bg-gray-100">${escapeHtml(situacao)}</span>`;
}
