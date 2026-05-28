<script lang="ts">
    import { onMount } from 'svelte';
    import * as echarts from 'echarts/core';
    import { BarChart } from 'echarts/charts';
    import { GridComponent, TooltipComponent } from 'echarts/components';
    import { CanvasRenderer } from 'echarts/renderers';
    import { isDarkMode } from '$lib/themeStore';

    let {
        totalSongs = 0,
        uniqueSongs = 0,
        titlePrefix = 'Song-Mix'
    } = $props();

    echarts.use([BarChart, GridComponent, TooltipComponent, CanvasRenderer]);

    let chartRef: HTMLDivElement;
    let chart: echarts.ECharts | null = null;

    let chartTheme = $derived({
        textColor: $isDarkMode ? '#e2e8f0' : '#1e293b',
        axisLineColor: $isDarkMode ? '#475569' : '#d1d5db',
        tooltipBackground: $isDarkMode ? '#334155' : '#ffffff'
    });

    function toInt(value: unknown) {
        const parsed = Number(value);
        if (!Number.isFinite(parsed)) return 0;
        return Math.max(0, Math.round(parsed));
    }

    function buildOptions() {
        const total = toInt(totalSongs);
        const unique = Math.min(toInt(uniqueSongs), total || toInt(uniqueSongs));
        const repeated = Math.max(0, total - unique);

        if (total === 0 && unique === 0) {
            return {
                graphic: {
                    type: 'text',
                    left: 'center',
                    top: 'middle',
                    style: {
                        text: 'Keine Songs vorhanden',
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
                textStyle: { color: chartTheme.textColor }
            },
            grid: {
                top: 18,
                left: 36,
                right: 18,
                bottom: 24,
                containLabel: true
            },
            xAxis: {
                type: 'value',
                minInterval: 1,
                axisLabel: { color: chartTheme.textColor },
                axisLine: { lineStyle: { color: chartTheme.axisLineColor } },
                splitLine: { lineStyle: { color: chartTheme.axisLineColor } }
            },
            yAxis: {
                type: 'category',
                data: ['Songs gesamt'],
                axisLabel: { color: chartTheme.textColor },
                axisLine: { lineStyle: { color: chartTheme.axisLineColor } }
            },
            series: [
                {
                    name: 'Unique',
                    type: 'bar',
                    stack: 'songs',
                    data: [unique],
                    itemStyle: { color: '#14b8a6', borderRadius: [6, 0, 0, 6] },
                    label: { show: unique > 0, position: 'insideLeft', formatter: '{c}', color: '#ffffff' }
                },
                {
                    name: 'Wiederholt',
                    type: 'bar',
                    stack: 'songs',
                    data: [repeated],
                    itemStyle: { color: '#8b5cf6', borderRadius: [0, 6, 6, 0] },
                    label: { show: repeated > 0, position: 'insideRight', formatter: '{c}', color: '#ffffff' }
                }
            ]
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
            totalSongs;
            uniqueSongs;
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
    <div bind:this={chartRef} class="w-full" style="height: 220px;"></div>
</div>

