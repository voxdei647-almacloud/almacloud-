const API_BASE_URL = "/api/v1";
let chartInstance = null;

function getAuthHeaders() {
    const token = localStorage.getItem('alma_jwt_token');
    const tenantId = localStorage.getItem('alma_tenant_id') || "11111111-1111-1111-1111-111111111111";

    if (!token) {
        window.location.href = "/ui/index.html";
        return null;
    }

    return {
        "Authorization": `Bearer ${token}`,
        "X-Tenant-ID": tenantId,
        "Content-Type": "application/json"
    };
}

async function initDashboard() {
    const headers = getAuthHeaders();
    if (!headers) return;

    document.getElementById('stat-tenant-id').textContent = localStorage.getItem('alma_tenant_id')?.substring(0, 8) + "...";

    await fetchSensors();
    await fetchEvents();
}

async function fetchSensors() {
    const headers = getAuthHeaders();
    try {
        const resp = await fetch(`${API_BASE_URL}/sensors`, { headers });
        if (resp.ok) {
            const sensors = await resp.json();
            document.getElementById('stat-active-sensors').textContent = sensors.length;
        }
    } catch (e) {
        console.error("Error fetching sensors:", e);
    }
}

async function fetchEvents() {
    const headers = getAuthHeaders();
    try {
        const resp = await fetch(`${API_BASE_URL}/telemetry/events`, { headers });
        if (resp.ok) {
            const events = await resp.json();
            renderEventsTable(events);
            updateMetricsAndChart(events);
        }
    } catch (e) {
        console.error("Error fetching events:", e);
    }
}

function renderEventsTable(events) {
    const tbody = document.getElementById('events-table-body');
    if (!events || events.length === 0) {
        tbody.innerHTML = '<tr><td colspan="5" class="p-4 text-center text-slate-500">Sin eventos de telemetría registrados.</td></tr>';
        return;
    }

    tbody.innerHTML = events.slice(0, 10).map(ev => {
        const sevClass = ev.severity === 'critical' ? 'bg-red-500/20 text-red-400 border-red-500/30' :
                         ev.severity === 'high' ? 'bg-amber-500/20 text-amber-400 border-amber-500/30' :
                         'bg-blue-500/20 text-blue-400 border-blue-500/30';
        return `
            <tr class="hover:bg-slate-800/50">
                <td class="p-2.5 font-medium">${ev.event_type}</td>
                <td class="p-2.5"><span class="px-2 py-0.5 rounded text-[10px] font-bold border ${sevClass}">${ev.severity.toUpperCase()}</span></td>
                <td class="p-2.5 font-mono text-slate-400">${ev.source_ip || 'N/A'}</td>
                <td class="p-2.5 font-mono text-slate-400">${ev.destination_ip || 'N/A'}</td>
                <td class="p-2.5 text-slate-500">${new Date(ev.timestamp).toLocaleTimeString()}</td>
            </tr>
        `;
    }).join('');
}

function updateMetricsAndChart(events) {
    document.getElementById('stat-total-events').textContent = events.length;

    const criticalCount = events.filter(e => e.severity === 'critical' || e.severity === 'high').length;
    document.getElementById('stat-critical-alerts').textContent = criticalCount;

    const counts = { critical: 0, high: 0, medium: 0, low: 0, info: 0 };
    events.forEach(e => {
        const s = e.severity.toLowerCase();
        if (counts[s] !== undefined) counts[s]++;
        else counts.info++;
    });

    renderChart(counts);
}

function renderChart(counts) {
    const ctx = document.getElementById('severityChart').getContext('2d');
    if (chartInstance) chartInstance.destroy();

    chartInstance = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: ['Critical', 'High', 'Medium', 'Low', 'Info'],
            datasets: [{
                data: [counts.critical, counts.high, counts.medium, counts.low, counts.info],
                backgroundColor: ['#ef4444', '#f59e0b', '#3b82f6', '#10b981', '#64748b'],
                borderWidth: 0
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { position: 'bottom', labels: { color: '#cbd5e1', font: { size: 10 } } }
            }
        }
    });
}

function logout() {
    localStorage.removeItem('alma_jwt_token');
    localStorage.removeItem('alma_tenant_id');
    window.location.href = "/ui/index.html";
}
