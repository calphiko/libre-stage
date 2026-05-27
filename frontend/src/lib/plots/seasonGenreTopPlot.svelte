<script lang="ts">
    import { onMount } from 'svelte';
    import * as echarts from 'echarts/core';
    import { BarChart } from 'echarts/charts';
    import { GridComponent, TooltipComponent, GraphicComponent } from 'echarts/components';
    import { CanvasRenderer } from 'echarts/renderers';
    import { isDarkMode } from '$lib/themeStore';

    let {
        genreDistribution = {},
        topN = 5,
        titlePrefix = 'Genres in dieser Saison'
    } = $props();

    echarts.use([BarChart, GridComponent, TooltipComponent, GraphicComponent, CanvasRenderer]);

    let chartRef: HTMLDivElement;
    let chart: echarts.ECharts | null = null;

    let chartTheme = $derived({
        textColor: $isDarkMode ? '#e2e8f0' : '#1e293b',
        axisLineColor: $isDarkMode ? '#475569' : '#d1d5db',
        tooltipBackground: $isDarkMode ? '#334155' : '#ffffff'
    });

    function normalizeEntries() {
        return Object.entries(genreDistribution || {})
            .map(([genre, count]) => ({
                genre: String(genre || 'Unbekannt'),
                count: Math.max(0, Number(count) || 0)
            }))
            .filter((entry) => entry.count > 0)
            .sort((a, b) => b.count - a.count)
            .slice(0, Math.max(1, Number(topN) || 5));
    }

    function buildOptions() {
        const entries = normalizeEntries();
        const total = entries.reduce((sum, entry) => sum + entry.count, 0);

        if (!entries.length || total <= 0) {
            return {
                graphic: {
                    type: 'text',
                    left: 'center',
                    top: 'middle',
                    style: {
                        text: 'Keine Genre-Daten vorhanden',
                        fill: chartTheme.textColor,
                        fontSize: 12
                    }
                }
            };
        }

        return {
            tooltip: {
                trigger: 'item',
                formatter: (params: any) => {
                    const value = Number(params?.value || 0);
                    const pct = Math.round((value / total) * 100);
                    return `${params?.name}: ${value} (${pct}%)`;
                },
                backgroundColor: chartTheme.tooltipBackground,
                borderColor: chartTheme.axisLineColor,
                textStyle: { color: chartTheme.textColor }
            },
            grid: {
                top: 10,
                left: 10,
                right: 20,
                bottom: 10,
                containLabel: true
            },
            xAxis: {
                type: 'value',
                axisLabel: { color: chartTheme.textColor },
                axisLine: { lineStyle: { color: chartTheme.axisLineColor } },
                splitLine: { lineStyle: { color: chartTheme.axisLineColor } }
            },
            yAxis: {
                type: 'category',
                inverse: true,
                data: entries.map((entry) => entry.genre),
                axisLabel: {
                    color: chartTheme.textColor,
                    width: 110,
                    overflow: 'truncate'
                },
                axisLine: { lineStyle: { color: chartTheme.axisLineColor } }
            },
            series: [{
                type: 'bar',
                data: entries.map((entry) => entry.count),
                barMaxWidth: 22,
                itemStyle: {
                    color: '#a855f7',
                    borderRadius: [0, 6, 6, 0]
                },
                label: {
                    show: true,
                    position: 'right',
                    color: chartTheme.textColor,
                    formatter: (params: any) => {
                        const value = Number(params?.value || 0);
                        const pct = Math.round((value / total) * 100);
                        return `${value}x (${pct}%)`;
                    }
                }
            }]
        };
    }

    function updateChart() {
        chart?.setOption(buildOptions(), true);
    }

    function handleResize() {
        chart?.resize();
    }

    onMount(() => {
        chart = echarts.init(chartRef);
        updateChart();
        window.addEventListener('resize', handleResize);

        return () => {
            window.removeEventListener('resize', handleResize);
            chart?.dispose();
        };
    });

    $effect(() => {
        if (chart) {
            genreDistribution;
            topN;
            updateChart();
        }
    });

    $effect(() => {
        if (chart && $isDarkMode !== undefined) {
            updateChart();
        }
    });
</script>

<div>
    <h5 class="text-xs font-semibold text-on-surface-variant mb-1">{titlePrefix}</h5>
    <div bind:this={chartRef} class="w-full h-[240px] sm:h-[250px] md:h-[260px]"></div>
</div>

