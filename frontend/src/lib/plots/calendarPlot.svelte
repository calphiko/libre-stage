<script lang="ts">
    import { onMount } from 'svelte';
    import * as echarts from 'echarts/core';
    import { CustomChart } from 'echarts/charts';
    import { CalendarComponent, TooltipComponent } from 'echarts/components';
    import { CanvasRenderer } from 'echarts/renderers';
    import { ChevronLeft, ChevronRight } from 'lucide-svelte';
    import { isDarkMode } from '$lib/themeStore';
    import { getInternalCalendar } from '$lib/api';

    echarts.use([CustomChart, CalendarComponent, TooltipComponent, CanvasRenderer]);

    type CalendarEntry = {
        kind: 'gig' | 'rehearsal';
        sort: string;
        title: string;
        time: string;
        details: (string | string[])[][];
    };

    const ICONS = {
        rehearsal: 'M7 18h2V6H7v12zm4 4h2V2h-2v20zm-8-8h2v-4H3v4zm12 4h2V6h-2v12zm4-8v4h2v-4h-2z',
        gig: 'M12 14c1.66 0 2.99-1.34 2.99-3L15 5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm5.3-3c0 3-2.54 5.1-5.3 5.1S6.7 14 6.7 11H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c3.28-.48 6-3.3 6-6.72h-1.7z'
    };
    const COLORS = { rehearsal: '#22c55e', gig: '#ef4444' };
    const KIND_NAMES = { rehearsal: 'Probe', gig: 'Gig' };
    // Icon offsets (relative to the cell's icon area) by number of entries
    const LAYOUTS = [
        [[0, 0]],
        [[-0.25, 0], [0.25, 0]],
        [[-0.3, 0], [0, 0], [0.3, 0]],
        [[-0.25, -0.2], [0.25, -0.2], [-0.25, 0.25], [0.25, 0.25]]
    ];

    let chartRef: HTMLDivElement;
    let chart = $state.raw<echarts.ECharts | null>(null);
    let month = $state(startOfMonth(new Date()));
    let loading = $state(false);
    let error = $state('');
    let entries = $state<Record<string, CalendarEntry[]>>({});
    let requestId = 0;

    let chartTheme = $derived({
        textColor: $isDarkMode ? '#e2e8f0' : '#1e293b',
        mutedColor: $isDarkMode ? '#94a3b8' : '#64748b',
        lineColor: $isDarkMode ? '#475569' : '#d1d5db',
        tooltipBackground: $isDarkMode ? '#334155' : '#ffffff'
    });

    let monthKey = $derived(toMonthKey(month));
    let monthTitle = $derived(month.toLocaleDateString('de-DE', { month: 'long', year: 'numeric' }));

    function startOfMonth(d: Date) {
        return new Date(d.getFullYear(), d.getMonth(), 1);
    }

    function pad(n: number) {
        return String(n).padStart(2, '0');
    }

    function toMonthKey(d: Date) {
        return `${d.getFullYear()}-${pad(d.getMonth() + 1)}`;
    }

    function shiftMonth(delta: number) {
        month = new Date(month.getFullYear(), month.getMonth() + delta, 1);
    }

    function daysOfMonth(d: Date): string[] {
        const count = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
        return Array.from({ length: count }, (_, i) => `${toMonthKey(d)}-${pad(i + 1)}`);
    }

    function escapeHtml(value: unknown) {
        return String(value).replace(
            /[&<>"']/g,
            (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!
        );
    }

    const hm = (value: unknown) => String(value).slice(0, 5);

    function buildEntries(payload: any): Record<string, CalendarEntry[]> {
        const result: Record<string, CalendarEntry[]> = {};
        const add = (day: string, entry: CalendarEntry) => (result[day] ??= []).push(entry);

        for (const reh of payload?.rehearsals ?? []) {
            const start = String(reh.begin);
            const begin = start.slice(11, 16);
            const end = reh.end ? String(reh.end).slice(11, 16) : '';
            const songs = (reh.songs ?? []).map((s: any) => `${s.interpret} – ${s.title}`);
            add(start.slice(0, 10), {
                kind: 'rehearsal',
                sort: begin,
                title: 'Probe',
                time: end ? `${begin}–${end} Uhr` : `${begin} Uhr`,
                details: [
                    ...(reh.comment ? [['Kommentar', reh.comment]] : []),
                    ...(songs.length ? [['Songs', songs]] : [])
                ]
            });
        }
        for (const gig of payload?.gigs ?? []) {
            const times = [
                gig.doors ? `Einlass ${hm(gig.doors)}` : '',
                gig.begin ? `Beginn ${hm(gig.begin)}` : '',
                gig.end ? `Ende ${hm(gig.end)}` : ''
            ].filter(Boolean);
            add(String(gig.datum), {
                kind: 'gig',
                sort: gig.begin ? hm(gig.begin) : '99:99',
                title: gig.name || 'Gig',
                time: times.join(' · '),
                details: [
                    ['Ort', gig.venue],
                    ['Veranstalter', gig.organizer],
                    ['Art', gig.kind_of_gig],
                    ['Status', gig.status],
                    ['Notizen', gig.notes]
                ].filter(([, v]) => v)
            });
        }
        for (const list of Object.values(result)) {
            list.sort((a, b) => a.sort.localeCompare(b.sort));
        }
        return result;
    }

    async function loadMonth(key: string) {
        const current = ++requestId;
        loading = true;
        error = '';
        try {
            const payload = await getInternalCalendar(key);
            if (current !== requestId) return;
            entries = buildEntries(payload);
        } catch (e) {
            if (current !== requestId) return;
            entries = {};
            error = 'Kalender konnte nicht geladen werden.';
        } finally {
            if (current === requestId) loading = false;
        }
    }

    function buildOption() {
        const theme = chartTheme;
        const days = daysOfMonth(month);
        const todayKey = new Date().toLocaleDateString('sv-SE');

        return {
            tooltip: {
                trigger: 'item',
                confine: true,
                backgroundColor: theme.tooltipBackground,
                borderColor: theme.lineColor,
                textStyle: { color: theme.textColor },
                extraCssText: 'max-width:340px;white-space:normal;',
                formatter: (params: any) => {
                    const day = days[params.dataIndex];
                    const list = entries[day] ?? [];
                    if (!list.length) return '';
                    const date = new Date(`${day}T00:00:00`).toLocaleDateString('de-DE', {
                        weekday: 'long',
                        day: '2-digit',
                        month: '2-digit'
                    });
                    const rows = list.map((e) => {
                        const details = e.details
                            .map(([label, value]) => {
                                const text = Array.isArray(value)
                                    ? value.map((v) => `<div style="padding-left:8px">• ${escapeHtml(v)}</div>`).join('')
                                    : ` ${escapeHtml(value)}`;
                                return `<div style="color:${theme.mutedColor}"><span>${label}:</span><span style="color:${theme.textColor}">${text}</span></div>`;
                            })
                            .join('');
                        return `<div style="margin-top:6px"><div><span style="color:${COLORS[e.kind]}">●</span> <b>${KIND_NAMES[e.kind]}${e.kind === 'gig' ? `: ${escapeHtml(e.title)}` : ''}</b></div>${e.time ? `<div style="color:${theme.mutedColor}">${escapeHtml(e.time)}</div>` : ''}${details}</div>`;
                    });
                    return `<div><b>${date}</b></div>${rows.join('')}`;
                }
            },
            calendar: {
                left: 4,
                right: 4,
                top: 22,
                bottom: 4,
                cellSize: ['auto', 'auto'],
                orient: 'vertical',
                silent: true,
                range: monthKey,
                yearLabel: { show: false },
                monthLabel: { show: false },
                dayLabel: { firstDay: 1, nameMap: 'de', color: theme.mutedColor },
                itemStyle: { color: 'transparent', borderColor: theme.lineColor, borderWidth: 1 },
                splitLine: { lineStyle: { color: theme.lineColor } }
            },
            series: [
                {
                    type: 'custom',
                    coordinateSystem: 'calendar',
                    z: 5,
                    renderItem: (params: any, api: any) => {
                        const day: string = days[params.dataIndex];
                        const cell = api.coord(day);
                        if (isNaN(cell[0]) || isNaN(cell[1])) return;

                        const { cellWidth, cellHeight } = params.coordSys;
                        const list = entries[day] ?? [];
                        const badge = Math.max(16, Math.min(24, cellHeight * 0.42));
                        const layout = LAYOUTS[Math.min(list.length, 4) - 1] ?? [];

                        const children: any[] = [
                            {
                                type: 'rect',
                                shape: {
                                    x: cell[0] - cellWidth / 2,
                                    y: cell[1] - cellHeight / 2,
                                    width: cellWidth,
                                    height: cellHeight
                                },
                                style: { fill: 'transparent' }
                            },
                            {
                                type: 'text',
                                style: {
                                    x: cell[0] - cellWidth / 2 + 6,
                                    y: cell[1] - cellHeight / 2 + 4,
                                    text: String(+day.slice(8)),
                                    fill: day === todayKey ? '#ffffff' : theme.mutedColor,
                                    font: api.font({ fontSize: 11, fontWeight: day === todayKey ? 'bold' : 'normal' }),
                                    backgroundColor: day === todayKey ? '#3b82f6' : 'transparent',
                                    borderRadius: 8,
                                    padding: day === todayKey ? [1, 5] : 0
                                }
                            }
                        ];

                        layout.forEach(([dx, dy]: number[], i: number) => {
                            const kind = list[i].kind;
                            const cx = cell[0] + dx * cellWidth;
                            const cy = cell[1] + dy * cellHeight + 6;
                            const inner = badge * 0.62;
                            children.push(
                                {
                                    type: 'circle',
                                    shape: { cx, cy, r: badge / 2 },
                                    style: { fill: COLORS[kind] }
                                },
                                {
                                    type: 'path',
                                    shape: {
                                        pathData: ICONS[kind],
                                        x: cx - inner / 2,
                                        y: cy - inner / 2,
                                        width: inner,
                                        height: inner
                                    },
                                    style: { fill: '#ffffff' }
                                }
                            );
                        });

                        return { type: 'group', children };
                    },
                    data: days.map((d) => [d])
                }
            ]
        };
    }

    $effect(() => {
        loadMonth(monthKey);
    });

    $effect(() => {
        if (!chart) return;
        chart.setOption(buildOption(), true);
    });

    onMount(() => {
        chart = echarts.init(chartRef);
        chart.setOption(buildOption(), true);
        const observer = new ResizeObserver(() => chart?.resize());
        observer.observe(chartRef);
        return () => {
            observer.disconnect();
            chart?.dispose();
            chart = null;
        };
    });
</script>

<div>
    <div class="flex items-center justify-between mb-1">
        <button
            type="button"
            class="p-1 rounded hover:bg-surface-container-high"
            aria-label="Voriger Monat"
            onclick={() => shiftMonth(-1)}
        >
            <ChevronLeft size={20} />
        </button>
        <div class="flex items-center gap-2">
            <span class="font-semibold text-on-surface">{monthTitle}</span>
            <button
                type="button"
                class="text-xs underline text-on-surface-variant"
                onclick={() => (month = startOfMonth(new Date()))}
            >
                Heute
            </button>
        </div>
        <button
            type="button"
            class="p-1 rounded hover:bg-surface-container-high"
            aria-label="Nächster Monat"
            onclick={() => shiftMonth(1)}
        >
            <ChevronRight size={20} />
        </button>
    </div>

    <div class="relative">
        <div bind:this={chartRef} class="w-full" style="height: 300px;"></div>
        {#if loading}
            <div class="absolute top-1 right-2 text-xs text-on-surface-variant">Lade…</div>
        {/if}
    </div>
    {#if error}
        <p class="text-sm text-error mt-1">{error}</p>
    {/if}

    <div class="flex gap-4 text-xs text-on-surface-variant mt-1">
        <span class="inline-flex items-center gap-1">
            <svg viewBox="0 0 24 24" width="16" height="16"><circle cx="12" cy="12" r="12" fill={COLORS.rehearsal} /><g transform="translate(6 6) scale(0.5)"><path d={ICONS.rehearsal} fill="#fff" /></g></svg>
            Probe
        </span>
        <span class="inline-flex items-center gap-1">
            <svg viewBox="0 0 24 24" width="16" height="16"><circle cx="12" cy="12" r="12" fill={COLORS.gig} /><g transform="translate(6 6) scale(0.5)"><path d={ICONS.gig} fill="#fff" /></g></svg>
            Gig
        </span>
    </div>
</div>
