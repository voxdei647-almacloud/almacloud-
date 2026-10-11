const API_BASE_URL = "/api/v1";

async function handleAuthSubmit(e) {
    e.preventDefault();
    const isSignUp = document.getElementById('tab-signup').classList.contains('bg-blue-600');
    const email = document.getElementById('email').value.trim();
    const password = document.getElementById('password').value;
    const tenantId = "11111111-1111-1111-1111-111111111111"; // Default Tenant Test

    if (isSignUp) {
        const fullName = document.getElementById('fullName').value.trim();
        showToast('Procesando', 'Creando cuenta en VOX DEI...');
        try {
            const resp = await fetch(`${API_BASE_URL}/auth/register`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "X-Tenant-ID": tenantId
                },
                body: JSON.stringify({ email, password, role: "admin" })
            });

            if (resp.status === 201) {
                showToast('¡Éxito!', 'Cuenta creada correctamente. Iniciando sesión...');
                setTimeout(() => loginUser(email, password, tenantId), 1000);
            } else {
                const err = await resp.json();
                showToast('Error', err.detail || 'Error registrando usuario');
            }
        } catch (exc) {
            showToast('Error', 'No se pudo conectar con el backend VOX DEI');
        }
    } else {
        showToast('Procesando', 'Autenticando credenciales...');
        loginUser(email, password, tenantId);
    }
}

async function loginUser(email, password, tenantId) {
    try {
        const resp = await fetch(`${API_BASE_URL}/auth/login`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "X-Tenant-ID": tenantId
            },
            body: JSON.stringify({ email, password })
        });

        if (resp.status === 200) {
            const data = await resp.json();
            localStorage.setItem('alma_jwt_token', data.access_token);
            localStorage.setItem('alma_tenant_id', data.tenant_id);
            showToast('¡Sesión Iniciada!', 'Redirigiendo al Dashboard SOC...');
            setTimeout(() => {
                window.location.href = "/ui/dashboard.html";
            }, 1200);
        } else {
            showToast('Error de Acceso', 'Credenciales o Tenant inválido');
        }
    } catch (exc) {
        showToast('Error', 'Error de red al autenticar');
    }
}
