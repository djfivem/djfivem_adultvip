(function () {
    const inGame = typeof window.GetParentResourceName === 'function';
    const app = document.getElementById('app');
    const nav = document.getElementById('nav');
    const categoriesEl = document.getElementById('categories');
    const grid = document.getElementById('grid');
    const panel = document.getElementById('panel');
    const profileEl = document.getElementById('profile');
    const selectionEl = document.getElementById('selection');
    const playerList = document.getElementById('player-list');
    const requestEl = document.getElementById('request');
    const overlay = document.getElementById('overlay');
    const hint = document.getElementById('hint');
    const toast = document.getElementById('toast');
    const search = document.getElementById('search');
    const statusEl = document.getElementById('status');
    const keysEl = document.getElementById('keys');
    const rolePill = document.getElementById('role-pill');

    const state = {
        view: 'browse',
        category: 'all',
        query: '',
        emotes: [],
        categories: [],
        favorites: new Set(),
        recent: [],
        players: [],
        selectedPlayer: null,
        selectedKey: null,
        invite: null,
        profile: { name: 'Player', serverId: 0, vip: false, admin: false },
        settings: {},
        admin: null,
        logs: [],
        resourceStarted: true,
        disabledCategories: {},
    };

    const icons = {
        browse: '<path d="M4 7 H20 M4 12 H20 M4 17 H14"/>',
        heart: '<path d="M12 19 S4 14 4 9 A4 4 0 0 1 12 8 A4 4 0 0 1 20 9 C20 14 12 19 12 19 Z"/>',
        clock: '<circle cx="12" cy="12" r="8"/><path d="M12 8 V12 L15 14"/>',
        users: '<circle cx="9" cy="9" r="3"/><circle cx="16" cy="10" r="2"/><path d="M4 18 C4 15 6 14 9 14 C12 14 14 15 14 18"/><path d="M14 18 C14 16 16 15 18 15 C20 15 21 16 21 18"/>',
        gear: '<circle cx="12" cy="12" r="3"/><path d="M12 3 V6 M12 18 V21 M3 12 H6 M18 12 H21 M5.5 5.5 L7.5 7.5 M16.5 16.5 L18.5 18.5 M18.5 5.5 L16.5 7.5 M7.5 16.5 L5.5 18.5"/>',
        info: '<circle cx="12" cy="12" r="8"/><path d="M12 11 V16 M12 8 H12"/>',
        shield: '<path d="M12 3 L19 6 V12 C19 16 16 19 12 21 C8 19 5 16 5 12 V6 Z"/>',
        flame: '<path d="M12 3 C14 7 18 8 18 13 A6 6 0 0 1 6 13 C6 9 9 8 10 5 C11 7 12 7 12 3 Z"/>',
        star: '<path d="M12 3 L14.5 8.5 L20 9 L16 13.5 L17 19 L12 16.5 L7 19 L8 13.5 L4 9 L9.5 8.5 Z"/>',
        play: '<path d="M8 6 L18 12 L8 18 Z"/>',
        close: '<path d="M6 6 L18 18 M18 6 L6 18"/>',
    };

    function svg(name) {
        return '<svg viewBox="0 0 24 24" aria-hidden="true">' + (icons[name] || icons.info) + '</svg>';
    }

    function escapeHtml(value) {
        return String(value ?? '').replace(/[&<>"']/g, function (char) {
            return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char];
        });
    }

    function cleanLabel(value) {
        return String(value ?? '').replace(/~[a-z0-9]~/gi, '');
    }

    function initials(name) {
        const parts = String(name || '?').trim().split(/\s+/).slice(0, 2);
        return parts.map(function (part) { return part.charAt(0).toUpperCase(); }).join('') || '?';
    }

    function post(name, data) {
        if (!inGame) return Promise.resolve(mock(name, data || {}));
        return fetch('https://' + GetParentResourceName() + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).then(function (response) { return response.json(); }).catch(function () { return { ok: false }; });
    }

    function showToast(message, kind) {
        toast.textContent = message;
        toast.className = 'toast' + (kind === 'error' ? ' is-error' : kind === 'success' ? ' is-success' : '');
        clearTimeout(showToast.timer);
        showToast.timer = setTimeout(function () { toast.classList.add('is-hidden'); }, 2800);
    }

    function selectedEmote() {
        return state.emotes.find(function (emote) { return emote.key === state.selectedKey; }) || null;
    }

    function selectedPlayer() {
        return state.players.find(function (player) { return player.id === state.selectedPlayer; }) || null;
    }

    function visibleEmotes() {
        const query = state.query.trim().toLowerCase();
        return state.emotes.filter(function (emote) {
            if (state.view === 'favorites' && !state.favorites.has(emote.key)) return false;
            if (state.view === 'recent' && state.recent.indexOf(emote.key) === -1) return false;
            if (state.view === 'browse' || state.view === 'favorites' || state.view === 'recent') {
                if (state.view === 'browse' && state.category === 'favorites' && !state.favorites.has(emote.key)) return false;
                if (state.view === 'browse' && state.category === 'paired' && !emote.paired) return false;
                if (state.view === 'browse' && state.category !== 'all' && state.category !== 'paired' && state.category !== 'favorites' && emote.category !== state.category) return false;
            }
            if (!query) return true;
            const haystack = (emote.label + ' ' + emote.key + ' ' + (emote.partnerLabel || '') + ' ' + emote.category).toLowerCase();
            return haystack.indexOf(query) !== -1;
        }).sort(function (a, b) {
            if (state.view === 'recent') return state.recent.indexOf(a.key) - state.recent.indexOf(b.key);
            return cleanLabel(a.label).localeCompare(cleanLabel(b.label));
        });
    }

    const navItems = [
        { id: 'browse', label: 'Browse Emotes', icon: 'browse' },
        { id: 'favorites', label: 'My Favorites', icon: 'heart' },
        { id: 'recent', label: 'Recent', icon: 'clock' },
        { id: 'players', label: 'Player Selection', icon: 'users' },
        { id: 'settings', label: 'Settings', icon: 'gear' },
        { id: 'about', label: 'About', icon: 'info' },
    ];

    function renderNav() {
        const items = navItems.slice();
        if (state.profile.admin) items.push({ id: 'admin', label: 'Admin', icon: 'shield' });
        nav.innerHTML = items.map(function (item) {
            return '<button type="button" data-view="' + item.id + '" class="' + (state.view === item.id ? 'is-active' : '') + '">' +
                svg(item.icon) + '<span>' + item.label + '</span></button>';
        }).join('');
    }

    function categoryCount(id) {
        if (id === 'all') return state.emotes.length;
        if (id === 'paired') return state.emotes.filter(function (emote) { return emote.paired; }).length;
        if (id === 'favorites') return state.emotes.filter(function (emote) { return state.favorites.has(emote.key); }).length;
        const match = state.categories.find(function (category) { return category.id === id; });
        if (match && typeof match.count === 'number' && !state.query) return match.count;
        return state.emotes.filter(function (emote) { return emote.category === id; }).length;
    }

    function renderCategories() {
        const show = state.view === 'browse' || state.view === 'favorites' || state.view === 'recent';
        categoriesEl.classList.toggle('is-hidden', !show || state.view !== 'browse');
        const items = [{ id: 'all', label: 'All' }, { id: 'paired', label: 'Paired' }, { id: 'favorites', label: 'Favorites' }]
            .concat(state.categories.map(function (category) { return { id: category.id, label: category.label }; }));
        const iconFor = { all: 'star', paired: 'users', favorites: 'heart', adult: 'flame', couples: 'heart', romantic: 'heart', positions: 'users', custom: 'star' };
        categoriesEl.innerHTML = items.map(function (item) {
            return '<button type="button" class="category' + (state.category === item.id ? ' is-active' : '') + '" data-category="' + item.id + '">' +
                '<div class="icon">' + svg(iconFor[item.id] || 'star') + '</div>' +
                '<strong>' + escapeHtml(item.label) + '</strong><span>' + categoryCount(item.id) + '</span></button>';
        }).join('');
    }

    function renderGrid() {
        const show = state.view === 'browse' || state.view === 'favorites' || state.view === 'recent';
        grid.classList.toggle('is-hidden', !show);
        panel.classList.toggle('is-hidden', show);
        if (!show) {
            renderPanel();
            return;
        }
        const emotes = visibleEmotes();
        if (!emotes.length) {
            const message = state.view === 'favorites'
                ? 'No favorites yet. Mark an animation with the heart.'
                : state.view === 'recent'
                    ? 'Animations you play show up here.'
                    : state.category === 'custom'
                        ? 'No custom emotes are enabled. Add shared emote ids from AnimationListCustom.lua, then restart.'
                        : 'No animations match. The server only lists clips that exist in RPEmotes and are enabled.';
            grid.innerHTML = '<div class="empty">' + message + '</div>';
            return;
        }
        grid.innerHTML = emotes.map(function (emote) {
            const label = cleanLabel(emote.label);
            return '<article class="card' + (state.selectedKey === emote.key ? ' is-selected' : '') + '" data-key="' + escapeHtml(emote.key) + '">' +
                '<div class="card-media"><em>' + escapeHtml(emote.category || 'emote') + '</em>' +
                '<button class="icon-btn' + (state.favorites.has(emote.key) ? ' is-on' : '') + '" type="button" data-fav="' + escapeHtml(emote.key) + '" aria-label="Favorite">' + svg('heart') + '</button>' +
                '<button class="play-btn" type="button" data-play="' + escapeHtml(emote.key) + '" aria-label="Use animation">' + svg('play') + '</button></div>' +
                '<div class="card-body"><h3>' + escapeHtml(label) + '</h3>' +
                '<div class="meta"><span class="chip">' + (emote.paired ? 'Paired' : 'Solo') + '</span>' +
                (emote.attach ? '<span class="chip">Synced</span>' : '') +
                (emote.prop ? '<span class="chip">Prop</span>' : '') + '</div>' +
                '<small>' + escapeHtml(emote.key) + (emote.partner ? ' · partner ' + escapeHtml(emote.partner) : '') + '</small></div></article>';
        }).join('');
    }

    function renderSelection() {
        const emote = selectedEmote();
        if (!emote) {
            selectionEl.innerHTML = '<h2>Selected</h2><p class="empty-copy">Choose an animation.</p>';
            return;
        }
        const player = selectedPlayer();
        const label = cleanLabel(emote.label);
        selectionEl.innerHTML = '<h2>Selected</h2><strong>' + escapeHtml(label) + '</strong>' +
            '<p class="empty-copy">' + (emote.paired
                ? 'Partner plays ' + escapeHtml(emote.partnerLabel || emote.partner || 'the matching clip') + '.'
                : 'Plays on you. RPEmotes runs the clip.') + '</p>' +
            '<div class="actions">' +
            (emote.paired
                ? '<button class="primary" type="button" data-action="invite"' + (player ? '' : ' disabled') + '>Request</button>'
                : '<button class="primary" type="button" data-action="solo">Play</button><button class="ghost" type="button" data-action="preview">Preview</button>') +
            '<button class="ghost" type="button" data-action="favorite">' + (state.favorites.has(emote.key) ? 'Unfavorite' : 'Favorite') + '</button></div>' +
            (emote.paired && !player ? '<p class="empty-copy">Select a nearby player to send the request.</p>' : '');
    }

    function renderPlayers() {
        if (!state.players.length) {
            playerList.innerHTML = '<p class="empty-copy">Nobody is within ' + escapeHtml(state.settings.distance || '') + 'm.</p>';
            return;
        }
        playerList.innerHTML = state.players.map(function (player) {
            return '<button type="button" class="player' + (state.selectedPlayer === player.id ? ' is-selected' : '') + '" data-player="' + player.id + '">' +
                '<div class="avatar sm">' + escapeHtml(initials(player.name)) + '</div>' +
                '<span><strong>' + escapeHtml(player.name) + '</strong><span>ID ' + escapeHtml(player.id) + '</span></span>' +
                '<em>' + escapeHtml(player.distance) + 'm</em></button>';
        }).join('');
    }

    function renderRequest() {
        const invite = state.invite;
        if (!invite) {
            requestEl.innerHTML = '<h2>Interaction Request</h2><p class="empty-copy">No pending request.</p>';
            return;
        }
        const remaining = Math.max(0, Math.ceil((invite.expiresAt - Date.now()) / 1000));
        requestEl.innerHTML = '<h2>Interaction Request</h2><strong>' + escapeHtml(cleanLabel(invite.label)) + '</strong>' +
            '<p class="empty-copy">' + escapeHtml(invite.otherName) + ' · ' + (invite.direction === 'incoming' ? 'incoming' : 'waiting') + ' · ' + remaining + 's</p>' +
            '<div class="actions">' +
            (invite.direction === 'incoming'
                ? '<button class="good" type="button" data-respond="yes">Accept</button><button class="bad" type="button" data-respond="no">Decline</button>'
                : '<button class="ghost" type="button" data-action="cancel-invite">Cancel</button>') +
            '</div>';
    }

    function renderOverlay() {
        const invite = state.invite;
        if (!invite || invite.direction !== 'incoming') {
            overlay.classList.add('is-hidden');
            overlay.innerHTML = '';
            return;
        }
        const total = invite.total || 15;
        const remaining = Math.max(0, invite.expiresAt - Date.now());
        const width = Math.max(0, Math.min(100, (remaining / (total * 1000)) * 100));
        overlay.classList.remove('is-hidden');
        overlay.innerHTML = '<div class="invite-card"><p class="kicker">Incoming request</p>' +
            '<h2 id="overlay-title">' + escapeHtml(invite.otherName) + '</h2>' +
            '<p>wants to play <strong>' + escapeHtml(cleanLabel(invite.label)) + '</strong> with you.</p>' +
            '<div class="timer"><span style="width:' + width + '%"></span></div>' +
            '<div class="invite-actions"><button class="good" type="button" data-respond="yes">Accept</button>' +
            '<button class="bad" type="button" data-respond="no">Decline</button></div></div>';
    }

    function renderProfile() {
        const profile = state.profile;
        profileEl.innerHTML = '<div class="avatar">' + escapeHtml(initials(profile.name)) + '</div><div><strong>' +
            escapeHtml(profile.name) + '</strong><span>ID ' + escapeHtml(profile.serverId) + '</span>' +
            (profile.vip ? '<div class="vip">VIP access</div>' : '') + '</div>';
        rolePill.textContent = state.settings.discordEnabled === false ? 'Discord check off' : 'Discord role required';
    }

    function renderKeys() {
        const settings = state.settings;
        keysEl.innerHTML = '<span><kbd>' + escapeHtml(settings.keybind || 'F6') + '</kbd>Menu</span>' +
            '<span><kbd>Esc</kbd>Close</span>' +
            '<span><kbd>' + escapeHtml(settings.cancelKey || 'X') + '</kbd>Cancel</span>';
    }

    function renderPanel() {
        if (state.view === 'players') {
            const emote = selectedEmote();
            panel.innerHTML = '<div class="panel-card"><h2>Player selection</h2><p>Pick someone in range, then send the paired animation. The other player has to accept before either clip starts.</p>' +
                '<p class="help">' + (emote ? 'Ready to request <strong>' + escapeHtml(cleanLabel(emote.label)) + '</strong>.' : 'Select an animation from Browse first.') + '</p></div>';
            return;
        }
        if (state.view === 'settings') {
            const settings = state.settings;
            panel.innerHTML = '<div class="panel-card"><h2>Settings</h2><p>Distance and the Discord role are enforced on the server.</p>' +
                '<p class="help">Command <strong>/' + escapeHtml(settings.command || 'djerp') + '</strong> · Key <strong>' + escapeHtml(settings.keybind || 'F6') + '</strong> · Cancel <strong>' + escapeHtml(settings.cancelKey || 'X') + '</strong></p>' +
                '<p class="help">Interaction distance <strong>' + escapeHtml(settings.distance || '-') + 'm</strong> · Request timeout <strong>' + escapeHtml(settings.timeout || '-') + 's</strong> · Cooldown <strong>' + escapeHtml(settings.cooldown || '-') + 's</strong></p>' +
                '<p class="help">Discord check: <strong>' + (settings.discordEnabled === false ? 'off' : 'on') + '</strong></p></div>';
            return;
        }
        if (state.view === 'about') {
            const studio = state.settings.studio || 'Phoenikera RP';
            panel.innerHTML = '<div class="about-hero"><img src="assets/brand-mark.webp" alt="' + escapeHtml(studio) + ' logo"><div>' +
                '<p class="kicker">' + escapeHtml(studio) + '</p><h2>' + escapeHtml(state.settings.title || 'DJ ERP MENU') + '</h2>' +
                '<p>Paired roleplay interactions for Phoenikera RP. RPEmotes plays the clips. This menu only offers identifiers that resource actually has, and only after the other player accepts.</p>' +
                '<p class="help">For 18+ communities. Access depends on the configured Discord role unless an admin bypass is granted.</p></div></div>';
            return;
        }
        if (state.view === 'admin' && state.profile.admin && state.admin) {
            renderAdmin();
            return;
        }
        panel.innerHTML = '<div class="panel-card"><h2>Admin</h2><p>You do not have the admin ace for this menu.</p></div>';
    }

    function renderAdmin() {
        const admin = state.admin;
        const categories = state.categories.map(function (category) {
            const off = state.disabledCategories[category.id] || (admin.disabledCategories && admin.disabledCategories[category.id]);
            return '<label><input type="checkbox" data-admin-category="' + escapeHtml(category.id) + '"' + (off ? '' : ' checked') + '> ' + escapeHtml(category.label) + '</label>';
        }).join('');
        const query = (state.adminQuery || '').toLowerCase();
        const rows = (admin.discovered || []).filter(function (entry) {
            if (!query) return true;
            return (entry.label + ' ' + entry.key).toLowerCase().indexOf(query) !== -1;
        }).slice(0, 40);
        panel.innerHTML = '<div class="admin-card"><h2>Server controls</h2>' +
            '<p class="help">Resource <strong>' + escapeHtml(admin.resource || 'not found') + '</strong> · parsed ' + escapeHtml(admin.parsed || 0) + ' · showing ' + escapeHtml(admin.shown || 0) + ' · token ' + (admin.tokenSet ? 'set' : 'missing') + '</p>' +
            '<div class="form-grid"><label class="field">Distance (m)<input id="admin-distance" type="number" min="1" max="' + escapeHtml(admin.maxDistance || 5) + '" step="0.1" value="' + escapeHtml(admin.distance) + '"></label>' +
            '<label class="field">Timeout (s)<input id="admin-timeout" type="number" min="5" max="60" step="1" value="' + escapeHtml(admin.timeout) + '"></label>' +
            '<label class="field">Cooldown (s)<input id="admin-cooldown" type="number" min="1" max="120" step="1" value="' + escapeHtml(admin.cooldown) + '"></label>' +
            '<label class="field">Discord guild id<input id="admin-guild" value="' + escapeHtml(admin.guildId || '') + '" placeholder="snowflake"></label></div>' +
            '<label class="field">Role ids, comma separated<input id="admin-roles" value="' + escapeHtml((admin.roleIds || []).join(', ')) + '"></label>' +
            '<label class="checks"><input id="admin-discord" type="checkbox"' + (admin.discordEnabled ? ' checked' : '') + '> Require the Discord role</label>' +
            '<div class="checks"><strong>Categories</strong>' + categories + '</div>' +
            '<div class="actions"><button class="primary" type="button" id="admin-save">Save limits and Discord</button>' +
            '<button class="ghost" type="button" id="admin-reload">Reload RPEmotes files</button>' +
            '<button class="ghost" type="button" id="admin-logs">Refresh logs</button></div>' +
            '<h2>Animations</h2><label class="field">Search discovered clips<input id="admin-search" value="' + escapeHtml(state.adminQuery || '') + '"></label>' +
            '<div class="discover">' + (rows.length ? rows.map(function (entry) {
                return '<button type="button" data-admin-emote="' + escapeHtml(entry.key) + '" data-enabled="' + (entry.enabled ? '1' : '0') + '">' +
                    escapeHtml(cleanLabel(entry.label)) + ' · ' + escapeHtml(entry.key) + ' · ' + (entry.enabled ? 'enabled' : 'hidden') + '</button>';
            }).join('') : '<p class="empty-copy">No clips match.</p>') + '</div>' +
            '<h2>Logs</h2><table><thead><tr><th>When</th><th>Action</th><th>Actor</th><th>Target</th><th>Emote</th></tr></thead><tbody>' +
            (state.logs.length ? state.logs.map(function (row) {
                const when = row.at ? new Date(Number(row.at) * 1000).toLocaleString() : '';
                return '<tr><td>' + escapeHtml(when) + '</td><td>' + escapeHtml(row.action) + '</td><td>' + escapeHtml(row.actorName || '') + '</td><td>' + escapeHtml(row.targetName || '') + '</td><td>' + escapeHtml(row.emote || '') + '</td></tr>';
            }).join('') : '<tr><td colspan="5">No interaction logs yet.</td></tr>') +
            '</tbody></table></div>';
        const adminSearch = document.getElementById('admin-search');
        if (adminSearch) {
            adminSearch.addEventListener('input', function () {
                state.adminQuery = adminSearch.value;
                renderAdmin();
                const again = document.getElementById('admin-search');
                if (again) {
                    again.focus();
                    again.setSelectionRange(again.value.length, again.value.length);
                }
            });
        }
    }

    function render() {
        renderNav();
        renderCategories();
        renderProfile();
        renderKeys();
        renderPlayers();
        renderSelection();
        renderRequest();
        renderOverlay();
        renderGrid();
        const title = document.getElementById('title');
        const subtitle = document.getElementById('subtitle');
        const kicker = document.getElementById('kicker');
        title.textContent = state.settings.title || 'DJ ERP MENU';
        subtitle.textContent = state.settings.subtitle || '';
        kicker.textContent = state.settings.studio || 'Phoenikera RP';
        const tagline = document.getElementById('sidebar-tagline');
        if (tagline) tagline.textContent = state.settings.tagline || 'Los Angeles · Desert Sunset';
        const barBrand = document.getElementById('keybar-brand');
        if (barBrand) barBrand.textContent = state.settings.studio || 'Phoenikera RP';
        if (!state.resourceStarted) {
            statusEl.textContent = 'RPEmotes is not running, so playback is unavailable. The catalog shown is whatever the server could read.';
            statusEl.classList.remove('is-hidden');
        } else {
            statusEl.classList.add('is-hidden');
        }
    }

    function setInvite(invite) {
        if (!invite) {
            state.invite = null;
        } else {
            const seconds = Number(invite.seconds) || 15;
            state.invite = {
                id: invite.id,
                direction: invite.direction,
                label: invite.label,
                emote: invite.emote,
                otherName: invite.otherName,
                otherId: invite.otherId,
                total: seconds,
                expiresAt: Date.now() + seconds * 1000,
            };
        }
        renderRequest();
        renderOverlay();
    }

    function applyMenu(menu) {
        if (!menu) return;
        state.emotes = menu.emotes || state.emotes;
        state.categories = menu.categories || state.categories;
        if (state.selectedKey && !state.emotes.some(function (emote) { return emote.key === state.selectedKey; })) {
            state.selectedKey = null;
        }
        render();
    }

    function openPayload(payload) {
        state.emotes = payload.emotes || [];
        state.categories = payload.categories || [];
        state.favorites = new Set(payload.favorites || []);
        state.recent = payload.recent || [];
        state.players = payload.players || [];
        state.profile = payload.profile || state.profile;
        state.settings = payload.settings || {};
        state.admin = payload.admin || null;
        state.resourceStarted = payload.resourceStarted !== false;
        state.disabledCategories = (payload.admin && payload.admin.disabledCategories) || {};
        app.classList.remove('is-hidden');
        render();
    }

    function mock(name, data) {
        if (name === 'close') {
            app.classList.add('is-hidden');
            return { ok: true };
        }
        if (name === 'favorite') {
            if (state.favorites.has(data.key)) state.favorites.delete(data.key);
            else state.favorites.add(data.key);
            render();
            showToast(state.favorites.has(data.key) ? 'Saved to favorites.' : 'Removed from favorites.', 'success');
            return { ok: true };
        }
        if (name === 'nearby') {
            showToast('Nearby list refreshed.', 'info');
            return { ok: true };
        }
        if (name === 'invite') {
            const player = state.players.find(function (item) { return item.id === Number(data.target); });
            const emote = state.emotes.find(function (item) { return item.key === data.emote; });
            setInvite({
                id: 'preview-out',
                direction: 'outgoing',
                label: emote ? emote.label : data.emote,
                otherName: player ? player.name : 'Player',
                seconds: state.settings.timeout || 15,
            });
            showToast('Request sent.', 'success');
            return { ok: true };
        }
        if (name === 'respond') {
            showToast(data.accepted ? 'Accepted. Both players would sync now.' : 'Declined.', data.accepted ? 'success' : 'info');
            setInvite(null);
            return { ok: true };
        }
        if (name === 'cancel') {
            setInvite(null);
            hint.classList.add('is-hidden');
            showToast('Cancelled.', 'info');
            return { ok: true };
        }
        if (name === 'solo' || name === 'preview') {
            const emote = state.emotes.find(function (item) { return item.key === data.key; });
            hint.classList.remove('is-hidden');
            hint.textContent = (name === 'preview' ? 'Preview' : 'Playing') + ' · ' + (emote ? cleanLabel(emote.label) : data.key) + ' · in game this calls RPEmotes Execute';
            showToast(name === 'preview' ? 'Preview requested.' : 'Solo emote requested.', 'success');
            if (!state.recent.includes(data.key)) state.recent.unshift(data.key);
            return { ok: true };
        }
        if (name === 'logs') {
            state.logs = state.logs.length ? state.logs : [{
                at: Math.floor(Date.now() / 1000),
                action: 'invite',
                actorName: state.profile.name,
                targetName: 'Luna Rose',
                emote: 'kiss',
            }];
            render();
            return { ok: true };
        }
        if (name === 'admin') {
            if (data.kind === 'category' && state.admin) {
                state.disabledCategories[data.id] = !data.enabled;
                if (state.admin.disabledCategories) state.admin.disabledCategories[data.id] = !data.enabled;
            }
            if (data.kind === 'emote' && state.admin) {
                state.admin.discovered.forEach(function (entry) {
                    if (entry.key === data.key) entry.enabled = data.enabled;
                });
                if (!data.enabled) {
                    state.emotes = state.emotes.filter(function (emote) { return emote.key !== data.key; });
                }
            }
            if (data.kind === 'distance') state.settings.distance = Number(data.value);
            showToast('Saved in this preview. In game the server validates it.', 'success');
            render();
            return { ok: true };
        }
        return { ok: true };
    }

    function useEmote(key, mode) {
        const emote = state.emotes.find(function (item) { return item.key === key; });
        if (!emote) return;
        state.selectedKey = key;
        if (emote.paired) {
            if (!state.selectedPlayer) {
                showToast('Select a nearby player first.', 'error');
                state.view = 'players';
                render();
                return;
            }
            post('invite', { target: state.selectedPlayer, emote: emote.key });
            return;
        }
        post(mode === 'play' ? 'solo' : 'preview', { key: emote.key });
    }

    document.getElementById('close').addEventListener('click', function () { post('close'); });
    document.getElementById('refresh-players').addEventListener('click', function () { post('nearby'); });
    search.addEventListener('input', function () {
        state.query = search.value;
        renderGrid();
        renderCategories();
    });

    document.body.addEventListener('click', function (event) {
        const view = event.target.closest('[data-view]');
        if (view) {
            state.view = view.getAttribute('data-view');
            if (state.view === 'favorites') state.category = 'favorites';
            if (state.view === 'browse' && (state.category === 'favorites')) state.category = 'all';
            if (state.view === 'admin') post('logs');
            render();
            return;
        }
        const category = event.target.closest('[data-category]');
        if (category) {
            state.view = 'browse';
            state.category = category.getAttribute('data-category');
            render();
            return;
        }
        const fav = event.target.closest('[data-fav]');
        if (fav) {
            event.stopPropagation();
            post('favorite', { key: fav.getAttribute('data-fav') });
            return;
        }
        const play = event.target.closest('[data-play]');
        if (play) {
            event.stopPropagation();
            const key = play.getAttribute('data-play');
            const emote = state.emotes.find(function (item) { return item.key === key; });
            useEmote(key, emote && emote.paired ? 'play' : 'preview');
            return;
        }
        const card = event.target.closest('.card');
        if (card) {
            state.selectedKey = card.getAttribute('data-key');
            renderGrid();
            renderSelection();
            return;
        }
        const player = event.target.closest('[data-player]');
        if (player) {
            state.selectedPlayer = Number(player.getAttribute('data-player'));
            renderPlayers();
            renderSelection();
            return;
        }
        const action = event.target.closest('[data-action]');
        if (action) {
            const kind = action.getAttribute('data-action');
            const emote = selectedEmote();
            if (kind === 'favorite' && emote) post('favorite', { key: emote.key });
            if (kind === 'solo' && emote) post('solo', { key: emote.key });
            if (kind === 'preview' && emote) post('preview', { key: emote.key });
            if (kind === 'invite' && emote) useEmote(emote.key, 'play');
            if (kind === 'cancel-invite') post('cancel');
            return;
        }
        const respond = event.target.closest('[data-respond]');
        if (respond && state.invite) {
            post('respond', { id: state.invite.id, accepted: respond.getAttribute('data-respond') === 'yes' });
            return;
        }
        const adminCategory = event.target.closest('[data-admin-category]');
        if (adminCategory) {
            post('admin', { kind: 'category', id: adminCategory.getAttribute('data-admin-category'), enabled: adminCategory.checked });
            return;
        }
        const adminEmote = event.target.closest('[data-admin-emote]');
        if (adminEmote) {
            const enabled = adminEmote.getAttribute('data-enabled') !== '1';
            post('admin', { kind: 'emote', key: adminEmote.getAttribute('data-admin-emote'), enabled: enabled, category: 'custom' });
            return;
        }
        if (event.target.id === 'admin-save' && state.admin) {
            const roles = document.getElementById('admin-roles').value.split(',').map(function (part) { return part.trim(); }).filter(Boolean);
            post('admin', { kind: 'distance', value: Number(document.getElementById('admin-distance').value) });
            post('admin', { kind: 'timeout', value: Number(document.getElementById('admin-timeout').value) });
            post('admin', { kind: 'cooldown', value: Number(document.getElementById('admin-cooldown').value) });
            post('admin', {
                kind: 'discord',
                discordEnabled: document.getElementById('admin-discord').checked,
                guildId: document.getElementById('admin-guild').value.trim(),
                roleIds: roles,
            });
            return;
        }
        if (event.target.id === 'admin-reload') post('admin', { kind: 'reload' });
        if (event.target.id === 'admin-logs') post('logs');
    });

    window.addEventListener('keydown', function (event) {
        if (event.key === 'Escape') {
            if (state.invite && state.invite.direction === 'incoming') {
                post('respond', { id: state.invite.id, accepted: false });
                return;
            }
            post('close');
        }
    });

    window.addEventListener('message', function (event) {
        const data = event.data || {};
        if (data.action === 'open') openPayload(data.payload || {});
        if (data.action === 'menu') {
            if (data.open === false) app.classList.add('is-hidden');
        }
        if (data.action === 'players') {
            state.players = data.players || [];
            renderPlayers();
        }
        if (data.action === 'favorites' && data.payload) {
            state.favorites = new Set(data.payload.favorites || []);
            showToast(data.payload.on ? 'Saved to favorites.' : 'Removed from favorites.', 'success');
            render();
        }
        if (data.action === 'invite') setInvite(data.invite);
        if (data.action === 'inviteClosed') {
            if (!state.invite || !data.payload || data.payload.id === state.invite.id) setInvite(null);
        }
        if (data.action === 'menuData') applyMenu(data.menu);
        if (data.action === 'admin') {
            state.admin = data.admin;
            state.disabledCategories = (data.admin && data.admin.disabledCategories) || {};
            if (state.view === 'admin') render();
        }
        if (data.action === 'logs') {
            state.logs = data.logs || [];
            if (state.view === 'admin') render();
        }
        if (data.action === 'toast' && data.message) showToast(data.message, data.kind);
        if (data.action === 'hint') {
            if (!data.show) {
                hint.classList.add('is-hidden');
            } else {
                hint.classList.remove('is-hidden');
                hint.textContent = (data.text || 'Playing') + (data.label ? ' · ' + data.label : '') + (data.session ? ' · press the cancel key to stop' : '');
            }
        }
    });

    setInterval(function () {
        if (!state.invite) return;
        if (Date.now() >= state.invite.expiresAt) {
            const expired = state.invite;
            setInvite(null);
            showToast(expired.direction === 'incoming' ? 'The request expired.' : 'Your request expired.', 'info');
            return;
        }
        renderRequest();
        renderOverlay();
    }, 250);

    function bootPreview() {
        const catalog = window.DJERP_PREVIEW_CATALOG || { emotes: [], categories: [] };
        const params = new URLSearchParams(window.location.search);
        openPayload({
            allowed: true,
            emotes: catalog.emotes || [],
            categories: catalog.categories || [],
            favorites: ['kiss', 'hugr'],
            recent: ['lapdance', 'fspose'],
            players: [
                { id: 12, name: 'Luna Rose', distance: 2.1 },
                { id: 18, name: 'Ryder Knox', distance: 3.4 },
                { id: 27, name: 'Jake Miller', distance: 4.8 },
            ],
            profile: { name: 'Acacia Bray', serverId: 42, vip: true, admin: true },
            settings: {
                title: 'DJ ERP MENU',
                subtitle: 'Choose an animation, pick a nearby player, and wait for them to accept.',
                studio: 'Phoenikera RP',
                tagline: 'Los Angeles · Desert Sunset',
                distance: 3,
                timeout: 15,
                cooldown: 8,
                command: 'djerp',
                keybind: 'F6',
                cancelKey: 'X',
                discordEnabled: true,
            },
            resourceStarted: true,
            admin: {
                resource: 'rpemotes-reborn',
                parsed: (catalog.emotes || []).length,
                shown: (catalog.emotes || []).length,
                tokenSet: false,
                distance: 3,
                timeout: 15,
                cooldown: 8,
                maxDistance: 5,
                discordEnabled: true,
                guildId: '',
                roleIds: [],
                disabledCategories: {},
                discovered: (catalog.emotes || []).map(function (emote) {
                    return { key: emote.key, label: emote.label, emoteType: emote.emoteType, enabled: true, category: emote.category, paired: emote.paired };
                }),
            },
        });
        state.logs = [{
            at: Math.floor(Date.now() / 1000) - 120,
            action: 'accept',
            actorName: 'Luna Rose',
            targetName: 'Acacia Bray',
            emote: 'kiss',
        }];
        if (params.get('category')) state.category = params.get('category');
        if (params.get('q')) {
            state.query = params.get('q');
            search.value = state.query;
        }
        if (params.get('view')) state.view = params.get('view');
        if (params.get('player')) state.selectedPlayer = Number(params.get('player'));
        if (params.get('emote')) state.selectedKey = params.get('emote');
        if (!state.selectedKey && state.emotes.length) state.selectedKey = 'kiss';
        if (params.get('invite') === '1' || state.view === 'invite') {
            state.view = 'browse';
            setInvite({
                id: 'preview-in',
                direction: 'incoming',
                label: 'Kiss',
                otherName: 'Luna Rose',
                seconds: 15,
            });
        }
        render();
    }

    if (!inGame) bootPreview();
})();
