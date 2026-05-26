<script lang="ts">
    import { onMount } from 'svelte';
    import * as echarts from 'echarts/core';
    import { PieChart, BarChart } from 'echarts/charts';
    import { GridComponent, TooltipComponent, LegendComponent, DataZoomComponent } from 'echarts/components';
    import { CanvasRenderer } from 'echarts/renderers';
    import { isDarkMode } from '$lib/themeStore';

    let {
        genreDistribution = {},
        genreTimeline = [],
        genrePalette = {},
        titlePrefix = 'Genre',
        showDistribution = true,
        showTimeline = true
    } = $props();

    echarts.use([PieChart, BarChart, GridComponent, TooltipComponent, LegendComponent, DataZoomComponent, CanvasRenderer]);

    let distributionChartRef: HTMLDivElement;
    let timelineChartRef: HTMLDivElement;
    let distributionChart: echarts.ECharts | null = null;
    let timelineChart: echarts.ECharts | null = null;

    const SERIES_COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#06b6d4', '#14b8a6', '#f97316'];

    let chartTheme = $derived({
        textColor: $isDarkMode ? '#e2e8f0' : '#1e293b',
        axisLineColor: $isDarkMode ? '#475569' : '#d1d5db',
        tooltipBackground: $isDarkMode ? '#334155' : '#ffffff'
    });

    function normalizeEventType(value: any) {
        const text = typeof value === 'string' ? value.trim() : '';
        return text || 'Unbekannt';
    }

    let eventTypes = $derived(Array.from(new Set((genreTimeline || []).map((point: any) => normalizeEventType(point?.kind_of_gig)))));
    let selectedEventType = $state('Alle');

    // Keep selection valid when timeline data changes.
    $effect(() => {
        if (selectedEventType !== 'Alle' && !eventTypes.includes(selectedEventType)) {
            selectedEventType = 'Alle';
        }
    });

    let filteredTimeline = $derived(
        (genreTimeline || []).filter((point: any) => {
            if (selectedEventType === 'Alle') return true;
            return normalizeEventType(point?.kind_of_gig) === selectedEventType;
        })
    );

    let filteredTimelineCount = $derived((filteredTimeline || []).length);
    let isCompactTimeline = $derived(filteredTimelineCount > 0 && filteredTimelineCount <= 8);
    let compactTimelineWidthPx = $derived(Math.max(460, Math.min(940, 220 + filteredTimelineCount * 92)));

    function normalizeGenreKey(genre: any) {
        return String(genre ?? '').trim().toLowerCase();
    }

    // Alphabetical, data-driven mapping so unknown genres still get stable colors.
    let allGenreKeysSorted = $derived.by(() => {
        const keys = new Set<string>();

        Object.keys(genreDistribution || {}).forEach((genre: string) => {
            const key = normalizeGenreKey(genre);
            if (key) keys.add(key);
        });

        (genreTimeline || []).forEach((point: any) => {
            Object.keys(point?.genre_counts || {}).forEach((genre: string) => {
                const key = normalizeGenreKey(genre);
                if (key) keys.add(key);
            });
        });

        return Array.from(keys).sort((a, b) => a.localeCompare(b, 'de', { sensitivity: 'base' }));
    });

    let genreColorMap = $derived.by(() =>
        (Array.isArray(allGenreKeysSorted) ? allGenreKeysSorted : []).reduce((acc: Record<string, string>, key: string, index: number) => {
            acc[key] = SERIES_COLORS[index % SERIES_COLORS.length];
            return acc;
        }, {})
    );

    let backendGenreColorMap = $derived.by(() =>
        Object.entries(genrePalette || {}).reduce((acc: Record<string, string>, [genre, color]) => {
            const key = normalizeGenreKey(genre);
            if (key && typeof color === 'string' && color.trim()) {
                acc[key] = color;
            }
            return acc;
        }, {})
    );

    function colorForGenre(genre: any) {
        const key = normalizeGenreKey(genre);
        return backendGenreColorMap[key] ?? genreColorMap[key] ?? SERIES_COLORS[0];
    }

    function shortenLabel(text: any, maxLength = 18) {
        const value = String(text ?? '').trim();
        if (!value) return '';
        return value.length > maxLength ? `${value.slice(0, maxLength - 1)}...` : value;
    }

    function formatTimelineLabel(point: any) {
        return shortenLabel(point?.label ?? '', 18);
    }

    function getAllGenres() {
        const genres = new Set<string>(Object.keys(genreDistribution || {}));
        (filteredTimeline || []).forEach((point: any) => {
            Object.keys(point?.genre_counts || {}).forEach((genre) => genres.add(genre));
        });
        return Array.from(genres).sort((a, b) => a.localeCompare(b));
    }

    function buildDistributionOptions() {
        const data = Object.entries(genreDistribution || {})
            .sort((a: any, b: any) => b[1] - a[1])
            .map(([genre, count]) => ({
                name: genre,
                value: count,
                itemStyle: { color: colorForGenre(genre) }
            }));

        return {
            tooltip: {
                trigger: 'item',
                formatter: '{b}: {c} ({d}%)',
                backgroundColor: chartTheme.tooltipBackground,
                borderColor: chartTheme.axisLineColor,
                textStyle: { color: chartTheme.textColor }
            },
            legend: {
                bottom: 0,
                textStyle: { color: chartTheme.textColor }
            },
            series: [{
                name: 'Genres',
                type: 'pie',
                radius: ['40%', '65%'],
                itemStyle: { borderRadius: 6 },
                label: {
                    show: true,
                    formatter: '{b}: {d}%',
                    color: chartTheme.textColor
                },
                data
            }]
        };
    }

    function buildTimelineOptions() {
        const genres = getAllGenres();
        const timeline = filteredTimeline || [];
        const hasManyBars = timeline.length > 12;

        if (!genres.length || !timeline.length) {
            return {
                graphic: {
                    type: 'text',
                    left: 'center',
                    top: 'middle',
                    style: {
                        text: 'Keine Daten fuer den gewaehlen Veranstaltungstyp',
                        fill: chartTheme.textColor,
                        fontSize: 12
                    }
                }
            };
        }

        return {
            tooltip: {
                trigger: 'axis',
                axisPointer: { type: 'shadow' },
                backgroundColor: chartTheme.tooltipBackground,
                borderColor: chartTheme.axisLineColor,
                textStyle: { color: chartTheme.textColor },
                valueFormatter: (value: number) => `${value.toFixed(1)}%`
            },
            legend: {
                top: 0,
                textStyle: { color: chartTheme.textColor }
            },
            grid: {
                top: 38,
                left: 34,
                right: 14,
                bottom: hasManyBars ? 52 : 28,
                containLabel: true
            },
            xAxis: {
                type: 'category',
                data: timeline.map((point: any) => formatTimelineLabel(point)),
                axisLabel: {
                    color: chartTheme.textColor,
                    interval: 0,
                    rotate: timeline.length > 4 ? 35 : 0,
                    hideOverlap: true,
                    width: 72,
                    overflow: 'truncate',
                    lineHeight: 12,
                    fontSize: 10
                },
                axisLine: {
                    lineStyle: { color: chartTheme.axisLineColor }
                }
            },
            yAxis: {
                type: 'value',
                min: 0,
                max: 100,
                axisLabel: {
                    color: chartTheme.textColor,
                    formatter: '{value}%'
                },
                axisLine: {
                    lineStyle: { color: chartTheme.axisLineColor }
                },
                splitLine: {
                    lineStyle: { color: chartTheme.axisLineColor }
                }
            },
            series: genres.map((genre) => ({
                name: genre,
                type: 'bar',
                stack: 'share',
                barMaxWidth: 26,
                barMinHeight: 1,
                itemStyle: { color: colorForGenre(genre) },
                data: timeline.map((point: any) => {
                    const genreCounts = point?.genre_counts || {};
                    const count = Number(genreCounts[genre] || 0);
                    const total = Number(point?.total || Object.values(genreCounts).reduce((sum: number, value: any) => sum + Number(value || 0), 0));
                    return total > 0 ? Number(((count / total) * 100).toFixed(1)) : 0;
                })
            })),
            barCategoryGap: hasManyBars ? '30%' : '44%',
            dataZoom: hasManyBars ? [
                {
                    type: 'inside',
                    xAxisIndex: 0,
                    startValue: 0,
                    endValue: 9
                },
                {
                    type: 'slider',
                    xAxisIndex: 0,
                    height: 14,
                    bottom: 4,
                    startValue: 0,
                    endValue: 9
                }
            ] : []
        };
    }

    function updateCharts() {
        if (showDistribution) distributionChart?.setOption(buildDistributionOptions(), true);
        if (showTimeline) timelineChart?.setOption(buildTimelineOptions(), true);
    }

    function handleResize() {
        if (showDistribution) distributionChart?.resize();
        if (showTimeline) timelineChart?.resize();
    }

    onMount(() => {
        if (showDistribution && distributionChartRef) distributionChart = echarts.init(distributionChartRef);
        if (showTimeline && timelineChartRef) timelineChart = echarts.init(timelineChartRef);
        updateCharts();
        window.addEventListener('resize', handleResize);

        return () => {
            window.removeEventListener('resize', handleResize);
            distributionChart?.dispose();
            timelineChart?.dispose();
        };
    });

    $effect(() => {
        if ((showDistribution ? !!distributionChart : true) && (showTimeline ? !!timelineChart : true) && genreDistribution && genreTimeline) {
            selectedEventType;
            filteredTimeline;
            updateCharts();
        }
    });

    $effect(() => {
        if ((showDistribution ? !!distributionChart : true) && (showTimeline ? !!timelineChart : true) && $isDarkMode !== undefined) {
            updateCharts();
        }
    });
</script>

{#if showTimeline && eventTypes.length > 1}
    <div class="flex justify-end mb-2">
        <label class="flex items-center gap-2 text-xs text-on-surface-variant">
            <span>Veranstaltungsart</span>
            <select class="select text-xs py-1" bind:value={selectedEventType}>
                <option value="Alle">Alle</option>
                {#each eventTypes as eventType}
                    <option value={eventType}>{eventType}</option>
                {/each}
            </select>
        </label>
    </div>
{/if}

{#if showDistribution && showTimeline}
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div>
            <h5 class="text-xs font-semibold text-on-surface-variant mb-1">{titlePrefix}: Relative Verteilung</h5>
            <div bind:this={distributionChartRef} class="w-full" style="height: 260px;"></div>
        </div>
        <div>
            <h5 class="text-xs font-semibold text-on-surface-variant mb-1">{titlePrefix}: Verteilung nach Sets/Gigs</h5>
            <div class="w-full">
                <div
                    bind:this={timelineChartRef}
                    class={isCompactTimeline ? 'mx-auto' : 'w-full'}
                    style="height: 260px; width: {isCompactTimeline ? `${compactTimelineWidthPx}px` : '100%'}; max-width: 100%;"
                ></div>
            </div>
        </div>
    </div>
{:else if showDistribution}
    <div>
        <h5 class="text-xs font-semibold text-on-surface-variant mb-1">{titlePrefix}: Relative Verteilung</h5>
        <div bind:this={distributionChartRef} class="w-full" style="height: 260px;"></div>
    </div>
{:else if showTimeline}
    <div>
        <h5 class="text-xs font-semibold text-on-surface-variant mb-1">{titlePrefix}: Verteilung nach Sets/Gigs</h5>
        <div class="w-full">
            <div
                bind:this={timelineChartRef}
                class={isCompactTimeline ? 'mx-auto' : 'w-full'}
                style="height: 260px; width: {isCompactTimeline ? `${compactTimelineWidthPx}px` : '100%'}; max-width: 100%;"
            ></div>
        </div>
    </div>
{/if}










