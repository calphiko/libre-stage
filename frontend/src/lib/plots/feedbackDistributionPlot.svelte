<script lang="ts">
    import { onMount } from 'svelte';
    import * as echarts from 'echarts/core';
    import { PieChart } from 'echarts/charts';
    import { TooltipComponent, LegendComponent } from 'echarts/components';
    import { CanvasRenderer } from 'echarts/renderers';
    import { isDarkMode } from '$lib/themeStore';

    let {
        feedbackDistribution = {},
        feedbackCount = 0,
        titlePrefix = 'Bewertungen'
    } = $props();

    echarts.use([PieChart, TooltipComponent, LegendComponent, CanvasRenderer]);

    let chartRef: HTMLDivElement;
    let chart: echarts.ECharts | null = null;

    const RATINGS = [
        { key: 3, emoji: '😍', label: 'Gut', color: '#10b981' },
        { key: 2, emoji: '😊', label: 'Mittel', color: '#f59e0b' },
        { key: 1, emoji: '😐', label: 'Schlecht', color: '#ef4444' }
    ];

    let chartTheme = $derived({
        textColor: $isDarkMode ? '#e2e8f0' : '#1e293b',
        axisLineColor: $isDarkMode ? '#475569' : '#d1d5db',
        tooltipBackground: $isDarkMode ? '#334155' : '#ffffff'
    });

    function buildOptions() {
        const data = RATINGS
            .map((rating) => ({
                name: `${rating.emoji} ${rating.label}`,
                value: Number((feedbackDistribution || {})[rating.key] || 0),
                itemStyle: { color: rating.color }
            }))
            .filter((entry) => entry.value > 0);

        if (!data.length || !feedbackCount) {
            return {
                graphic: {
                    type: 'text',
                    left: 'center',
                    top: 'middle',
                    style: {
                        text: 'Keine Bewertungen vorhanden',
                        fill: chartTheme.textColor,
                        fontSize: 12
                    }
                }
            };
        }

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
                name: titlePrefix,
                type: 'pie',
                radius: ['42%', '68%'],
                itemStyle: { borderRadius: 6 },
                label: {
                    show: true,
                    formatter: '{d}%',
                    color: chartTheme.textColor
                },
                data
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
            feedbackDistribution;
            feedbackCount;
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
    <h5 class="text-xs font-semibold text-on-surface-variant mb-1">{titlePrefix}: Verteilung</h5>
    <div bind:this={chartRef} class="w-full" style="height: 220px;"></div>
</div>

