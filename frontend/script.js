cat > script.js << 'EOF'
// ============================================
// SCRIPT.JS - Frontend JavaScript for LinkHub
// Handles: API calls, UI interactions, state management
// ============================================

// ============================================
// Global Variables
// ============================================
const API_URL = 'http://localhost:5000';
let currentUser = null;
let userLinks = [];

// ============================================
// Utility Functions
// ============================================

// Show toast notification
function showToast(message, type = 'success') {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = message;
    document.body.appendChild(toast);
    
    setTimeout(() => {
        toast.remove();
    }, 3000);
}

// Format date
function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    });
}

// Get platform icon
function getPlatformIcon(platform) {
    const icons = {
        'Instagram': '📸',
        'YouTube': '🎥',
        'Twitter': '🐦',
        'TikTok': '🎵',
        'GitHub': '💻',
        'LinkedIn': '💼',
        'Facebook': '📘',
        'Website': '🌐',
        'Newsletter': '📧',
        'Podcast': '🎧',
        'Twitch': '🎮',
        'Discord': '💬',
        'Spotify': '🎵'
    };
    return icons[platform] || '🔗';
}

// Escape HTML to prevent XSS
function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Validate URL
function isValidUrl(url) {
    try {
        new URL(url);
        return true;
    } catch {
        return false;
    }
}

// ============================================
// Authentication Functions
// ============================================

// Check if user is logged in
function isLoggedIn() {
    const token = localStorage.getItem('token');
    return !!token;
}

// Get auth token
function getAuthToken() {
    return localStorage.getItem('token');
}

// Save auth token
function setAuthToken(token) {
    localStorage.setItem('token', token);
}

// Clear auth data
function logout() {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    window.location.href = 'index.html';
}

// Get current user from localStorage
function getCurrentUser() {
    const userStr = localStorage.getItem('user');
    if (userStr) {
        return JSON.parse(userStr);
    }
    return null;
}

// ============================================
// API Calls
// ============================================

// Generic API request function
async function apiRequest(endpoint, options = {}) {
    const token = getAuthToken();
    
    const headers = {
        'Content-Type': 'application/json',
        ...options.headers
    };
    
    if (token) {
        headers['Authorization'] = `Bearer ${token}`;
    }
    
    const config = {
        ...options,
        headers
    };
    
    try {
        const response = await fetch(`${API_URL}${endpoint}`, config);
        const data = await response.json();
        
        if (!response.ok) {
            throw new Error(data.message || 'Request failed');
        }
        
        return data;
    } catch (error) {
        console.error('API Error:', error);
        throw error;
    }
}

// Signup
async function signup(email, username, password, displayName = '') {
    return apiRequest('/api/signup', {
        method: 'POST',
        body: JSON.stringify({ email, username, password, display_name: displayName })
    });
}

// Login
async function login(email, password) {
    return apiRequest('/api/login', {
        method: 'POST',
        body: JSON.stringify({ email, password })
    });
}

// Get user profile
async function getUserProfile() {
    return apiRequest('/api/user');
}

// Get user links
async function getUserLinks() {
    return apiRequest('/api/links');
}

// Add link
async function addLink(platform, url) {
    return apiRequest('/api/links', {
        method: 'POST',
        body: JSON.stringify({ platform, url })
    });
}

// Delete link
async function deleteLink(linkId) {
    return apiRequest(`/api/links/${linkId}`, {
        method: 'DELETE'
    });
}

// Get stats
async function getStats() {
    return apiRequest('/api/stats');
}

// Get public profile
async function getPublicProfile(username) {
    return apiRequest(`/api/profile/${username}`);
}

// Track click
async function trackClick(linkId) {
    return apiRequest(`/api/click/${linkId}`, {
        method: 'POST'
    });
}

// ============================================
// Dashboard Functions
// ============================================

// Load dashboard data
async function loadDashboard() {
    if (!isLoggedIn()) {
        window.location.href = 'login.html';
        return;
    }
    
    try {
        const [user, links, stats] = await Promise.all([
            getUserProfile(),
            getUserLinks(),
            getStats()
        ]);
        
        currentUser = user;
        userLinks = links.links || [];
        
        updateStats(stats);
        renderLinks();
        updateProfileLink();
        
    } catch (error) {
        console.error('Error loading dashboard:', error);
        showToast('Failed to load dashboard', 'error');
    }
}

// Update stats display
function updateStats(stats) {
    const totalLinksEl = document.getElementById('totalLinks');
    const totalClicksEl = document.getElementById('totalClicks');
    const topPlatformEl = document.getElementById('topPlatform');
    
    if (totalLinksEl) totalLinksEl.textContent = stats.total_links || 0;
    if (totalClicksEl) totalClicksEl.textContent = stats.total_clicks || 0;
    if (topPlatformEl) topPlatformEl.textContent = stats.top_link?.platform || '-';
}

// Render links list
function renderLinks() {
    const container = document.getElementById('linksList');
    
    if (!container) return;
    
    if (userLinks.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-icon">🔗</div>
                <p>No links yet. Add your first link above!</p>
            </div>
        `;
        return;
    }
    
    container.innerHTML = userLinks.map(link => `
        <div class="link-item" data-id="${link.id}">
            <div class="link-info">
                <div class="drag-handle" style="cursor: move;">⋮⋮</div>
                <div class="link-icon">${getPlatformIcon(link.platform)}</div>
                <div class="link-details">
                    <div class="link-platform">${escapeHtml(link.platform)}</div>
                    <div class="link-url">${escapeHtml(link.url)}</div>
                </div>
            </div>
            <div class="link-stats">
                <div class="click-count">${link.clicks || 0}</div>
                <div style="font-size: 12px; color: #666;">clicks</div>
            </div>
            <div class="link-actions">
                <button class="btn-icon btn-delete" onclick="handleDeleteLink(${link.id})" title="Delete">🗑️</button>
            </div>
        </div>
    `).join('');
}

// Handle add link
async function handleAddLink() {
    const platform = document.getElementById('platform')?.value;
    const url = document.getElementById('url')?.value;
    
    if (!url) {
        showToast('Please enter a URL', 'error');
        return;
    }
    
    if (!isValidUrl(url)) {
        showToast('Please enter a valid URL (start with http:// or https://)', 'error');
        return;
    }
    
    try {
        await addLink(platform, url);
        showToast('Link added successfully!');
        
        // Clear input
        if (document.getElementById('url')) {
            document.getElementById('url').value = '';
        }
        
        // Reload dashboard
        await loadDashboard();
        
    } catch (error) {
        showToast(error.message || 'Failed to add link', 'error');
    }
}

// Handle delete link
async function handleDeleteLink(linkId) {
    if (!confirm('Are you sure you want to delete this link?')) return;
    
    try {
        await deleteLink(linkId);
        showToast('Link deleted successfully!');
        await loadDashboard();
    } catch (error) {
        showToast(error.message || 'Failed to delete link', 'error');
    }
}

// Update profile link display
function updateProfileLink() {
    const profileLink = document.getElementById('publicPageLink');
    if (profileLink && currentUser) {
        const url = `${API_URL}/api/profile/${currentUser.username}`;
        profileLink.href = url;
        profileLink.textContent = `LinkHub/${currentUser.username}`;
    }
}

// ============================================
// Form Handling
// ============================================

// Handle login form
async function handleLogin(event) {
    event.preventDefault();
    
    const email = document.getElementById('email')?.value;
    const password = document.getElementById('password')?.value;
    
    if (!email || !password) {
        showToast('Please fill in all fields', 'error');
        return;
    }
    
    try {
        const data = await login(email, password);
        setAuthToken(data.token);
        localStorage.setItem('user', JSON.stringify(data.user));
        showToast('Login successful! Redirecting...');
        
        setTimeout(() => {
            window.location.href = 'dashboard.html';
        }, 1000);
        
    } catch (error) {
        showToast(error.message || 'Login failed', 'error');
    }
}

// Handle signup form
async function handleSignup(event) {
    event.preventDefault();
    
    const email = document.getElementById('email')?.value;
    const username = document.getElementById('username')?.value;
    const displayName = document.getElementById('displayName')?.value;
    const password = document.getElementById('password')?.value;
    const confirmPassword = document.getElementById('confirmPassword')?.value;
    
    if (!email || !username || !password) {
        showToast('Please fill in all required fields', 'error');
        return;
    }
    
    if (password !== confirmPassword) {
        showToast('Passwords do not match', 'error');
        return;
    }
    
    if (password.length < 6) {
        showToast('Password must be at least 6 characters', 'error');
        return;
    }
    
    try {
        const data = await signup(email, username, password, displayName);
        setAuthToken(data.token);
        localStorage.setItem('user', JSON.stringify(data.user));
        showToast('Account created! Redirecting...');
        
        setTimeout(() => {
            window.location.href = 'dashboard.html';
        }, 1500);
        
    } catch (error) {
        showToast(error.message || 'Signup failed', 'error');
    }
}

// ============================================
// Event Listeners
// ============================================

// Initialize dashboard
document.addEventListener('DOMContentLoaded', () => {
    // Dashboard page
    const dashboardBtn = document.getElementById('addLinkBtn');
    if (dashboardBtn) {
        dashboardBtn.addEventListener('click', handleAddLink);
        loadDashboard();
    }
    
    // Login page
    const loginForm = document.getElementById('loginForm');
    if (loginForm) {
        loginForm.addEventListener('submit', handleLogin);
    }
    
    // Signup page
    const signupForm = document.getElementById('signupForm');
    if (signupForm) {
        signupForm.addEventListener('submit', handleSignup);
    }
    
    // Logout button
    const logoutBtn = document.getElementById('logoutBtn');
    if (logoutBtn) {
        logoutBtn.addEventListener('click', (e) => {
            e.preventDefault();
            logout();
        });
    }
});

// ============================================
// Export for use in other files
// ============================================
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        signup,
        login,
        addLink,
        deleteLink,
        getStats,
        getPublicProfile,
        trackClick,
        showToast,
        isValidUrl
    };
}
EOF