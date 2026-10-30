{{--
    The record View pop-up's look (App\Filament\Support\RecordView), after
    the ehhs admin's provider screens: every value in its own boxed tile
    with a small uppercase label. Scoped to .sm-tiles, so only sections
    built through RecordView::section() change.

    Inline on purpose: the panel has no CSS build step (CLAUDE.md — the
    panel-provider colour config is the only theming). The classes are
    Filament's own infolist class names; if a Filament upgrade renames
    them, the values simply show without boxes — nothing breaks.
--}}
<style>
    .sm-tiles .fi-in-entry-wrp {
        height: 100%;
        padding: 0.6rem 0.8rem;
        border-radius: 0.6rem;
        background: rgba(148, 163, 184, 0.07);
        border: 1px solid rgba(148, 163, 184, 0.16);
    }

    .sm-tiles .fi-in-entry-wrp-label {
        font-size: 0.68rem;
        letter-spacing: 0.05em;
        text-transform: uppercase;
        opacity: 0.75;
    }

    /* A repeatable list (documents) keeps its own cards un-boxed inside. */
    .sm-tiles .fi-in-repeatable .fi-in-entry-wrp {
        padding: 0;
        background: none;
        border: 0;
    }

    .sm-tiles .fi-in-repeatable-item {
        border-radius: 0.6rem;
        background: rgba(148, 163, 184, 0.07);
        border: 1px solid rgba(148, 163, 184, 0.16);
    }

    /*
     * Page descriptions (getSubheading()) run the full width of the page.
     * Filament caps them at max-w-2xl, which wrapped one sentence over four
     * lines once the panels went full width (maxContentWidth(Full)).
     */
    .fi-header-subheading {
        max-width: none;
    }

    /*
     * Header buttons (New zone, New document type…) sit on the title's row,
     * not centred against title + description. Filament's own sm:mt-7 on the
     * button group already clears the breadcrumbs, so top-aligning is enough.
     */
    @media (min-width: 640px) {
        .fi-header {
            align-items: flex-start;
        }
    }

    /*
     * Stand-alone tab bars (list count tabs, Edit-page relation tabs, page
     * sub-navigation) start at the left edge. Filament centres them with
     * mx-auto; tabs inside a form (fi-contained) were already left.
     */
    .fi-tabs:not(.fi-contained) {
        margin-left: 0;
        margin-right: auto;
    }

    /*
     * Table footer: "Showing…" on the left, the Per page select and the page
     * numbers together on the right — Filament centres the select in its own
     * column. From md up only; below that Filament shows Previous / Next
     * buttons instead and its own grid suits them.
     */
    @media (min-width: 768px) {
        .fi-pagination:not(.fi-simple) {
            display: flex;
        }

        .fi-pagination:not(.fi-simple) .fi-pagination-overview {
            margin-right: auto;
        }
    }
</style>
