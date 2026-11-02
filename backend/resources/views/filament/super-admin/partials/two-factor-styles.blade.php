{{--
    Shared look for the two-step login pages (challenge + setup). Plain CSS
    on Filament's own colour variables — no Tailwind build, no CDN (CLAUDE.md:
    the panel has no custom Tailwind build, and no third-party scripts).
--}}
<style>
    .tf-wrap { max-width: 30rem; margin: 2rem auto 0; }
    .tf-wrap.tf-wide { max-width: 44rem; }
    .tf-card {
        border-radius: 1rem; padding: 2rem 1.75rem;
        background: #fff; border: 1px solid rgba(var(--gray-950), 0.08);
        box-shadow: 0 10px 30px rgba(0, 0, 0, 0.06);
    }
    .dark .tf-card { background: rgb(var(--gray-900)); border-color: rgba(255, 255, 255, 0.08); box-shadow: 0 10px 30px rgba(0, 0, 0, 0.35); }
    .tf-card + .tf-card { margin-top: 1rem; }

    .tf-icon {
        width: 3.5rem; height: 3.5rem; margin: 0 auto 1rem; border-radius: 9999px;
        display: grid; place-items: center;
        background: rgba(var(--primary-500), 0.12); color: rgb(var(--primary-600));
        box-shadow: 0 0 0 6px rgba(var(--primary-500), 0.06);
    }
    .dark .tf-icon { color: rgb(var(--primary-400)); }
    .tf-icon svg { width: 1.75rem; height: 1.75rem; }

    .tf-title { text-align: center; font-size: 1.375rem; font-weight: 700; letter-spacing: -0.01em; color: rgb(var(--gray-950)); }
    .dark .tf-title { color: #fff; }
    .tf-sub { margin-top: 0.4rem; text-align: center; font-size: 0.875rem; line-height: 1.5; color: rgb(var(--gray-500)); }
    .dark .tf-sub { color: rgb(var(--gray-400)); }
    .tf-sub strong { color: rgb(var(--gray-800)); font-weight: 600; }
    .dark .tf-sub strong { color: rgb(var(--gray-200)); }

    .tf-form { margin-top: 1.5rem; }
    .tf-code-input {
        text-align: center !important; font-size: 1.5rem !important; font-weight: 600 !important;
        letter-spacing: 0.45em !important; padding-top: 0.75rem !important; padding-bottom: 0.75rem !important;
        font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace !important;
    }
    .tf-code-input::placeholder { letter-spacing: 0.45em; opacity: 0.35; }
    .tf-btn-full { margin-top: 1rem; }
    .tf-btn-full > * { width: 100%; justify-content: center; }

    .tf-divider { display: flex; align-items: center; gap: 0.75rem; margin: 1.5rem 0 1rem; font-size: 0.75rem; color: rgb(var(--gray-400)); }
    .tf-divider::before, .tf-divider::after { content: ""; flex: 1; height: 1px; background: rgba(var(--gray-500), 0.2); }

    .tf-link { display: block; width: 100%; text-align: center; font-size: 0.875rem; font-weight: 600; color: rgb(var(--primary-600)); background: none; border: 0; cursor: pointer; }
    .dark .tf-link { color: rgb(var(--primary-400)); }
    .tf-link:hover { text-decoration: underline; }

    .tf-note {
        margin-top: 1.25rem; padding: 0.75rem 0.9rem; border-radius: 0.75rem; font-size: 0.8rem; line-height: 1.5;
        background: rgba(var(--gray-500), 0.08); color: rgb(var(--gray-600));
    }
    .dark .tf-note { background: rgba(255, 255, 255, 0.04); color: rgb(var(--gray-400)); }
    .tf-note strong { color: rgb(var(--gray-800)); }
    .dark .tf-note strong { color: rgb(var(--gray-200)); }
    .tf-note.tf-warn { background: rgba(var(--warning-500), 0.1); color: rgb(var(--warning-700)); }
    .dark .tf-note.tf-warn { color: rgb(var(--warning-400)); }

    /* Setup: numbered steps, the key box, the recovery codes grid. */
    .tf-step { display: flex; gap: 0.9rem; }
    .tf-step-num {
        flex: none; width: 1.75rem; height: 1.75rem; border-radius: 9999px; display: grid; place-items: center;
        font-size: 0.8rem; font-weight: 700; background: rgb(var(--primary-600)); color: #fff;
    }
    .tf-step-title { font-size: 1rem; font-weight: 600; color: rgb(var(--gray-950)); }
    .dark .tf-step-title { color: #fff; }
    .tf-step-body { flex: 1; min-width: 0; }
    .tf-step-body p { margin-top: 0.3rem; font-size: 0.875rem; line-height: 1.55; color: rgb(var(--gray-500)); }
    .dark .tf-step-body p { color: rgb(var(--gray-400)); }

    .tf-fields { margin-top: 1rem; display: grid; grid-template-columns: repeat(auto-fit, minmax(11rem, 1fr)); gap: 0.75rem; }
    .tf-field { padding: 0.7rem 0.85rem; border-radius: 0.75rem; background: rgba(var(--gray-500), 0.08); }
    .dark .tf-field { background: rgba(255, 255, 255, 0.04); }
    .tf-field dt { font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.06em; color: rgb(var(--gray-500)); }
    .tf-field dd { margin-top: 0.2rem; font-size: 0.9rem; font-weight: 600; word-break: break-all; color: rgb(var(--gray-900)); }
    .dark .tf-field dd { color: rgb(var(--gray-100)); }

    .tf-key { display: flex; align-items: center; justify-content: space-between; gap: 0.75rem; margin-top: 0.75rem;
        padding: 0.85rem 1rem; border-radius: 0.75rem; border: 1px dashed rgba(var(--primary-500), 0.5); background: rgba(var(--primary-500), 0.06); }
    .tf-key code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 1.05rem; font-weight: 600; letter-spacing: 0.12em; word-break: break-all; color: rgb(var(--gray-900)); user-select: all; }
    .dark .tf-key code { color: #fff; }

    .tf-codes { margin-top: 1rem; display: grid; grid-template-columns: repeat(auto-fill, minmax(9.5rem, 1fr)); gap: 0.5rem; }
    .tf-codes li { padding: 0.6rem 0.5rem; border-radius: 0.6rem; text-align: center; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 0.9rem; font-weight: 600; letter-spacing: 0.04em;
        background: rgba(var(--gray-500), 0.08); color: rgb(var(--gray-900)); }
    .dark .tf-codes li { background: rgba(255, 255, 255, 0.05); color: #fff; }
    .tf-actions { margin-top: 1rem; display: flex; flex-wrap: wrap; gap: 0.5rem; }
</style>
