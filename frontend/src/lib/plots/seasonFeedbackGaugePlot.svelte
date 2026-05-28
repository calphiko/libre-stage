<script lang="ts">
    import { onMount } from 'svelte';
    import * as echarts from 'echarts/core';
    import { GaugeChart } from 'echarts/charts';
    import { TooltipComponent, GraphicComponent } from 'echarts/components';
    import { CanvasRenderer } from 'echarts/renderers';
    import { isDarkMode } from '$lib/themeStore';

    let {
        feedbackAvg = null,
        feedbackCount = 0,
        titlePrefix = 'Feedback-Durchschnitt'
    } = $props();

    echarts.use([GaugeChart, TooltipComponent, GraphicComponent, CanvasRenderer]);

    let chartRef: HTMLDivElement;
    let chart: echarts.ECharts | null = null;

    let chartTheme = $derived({
        textColor: $isDarkMode ? '#e2e8f0' : '#1e293b',
        axisLineColor: $isDarkMode ? '#475569' : '#d1d5db',
        tooltipBackground: $isDarkMode ? '#334155' : '#ffffff'
    });

    function toFloat(value: unknown) {
        const parsed = Number(value);
        if (!Number.isFinite(parsed)) return null;
        return parsed;
    }

    function emojiFor(value: number) {
        if (value >= 2.5) return ':)';
        if (value >= 1.5) return ':|';
        return ':(';
    }

    function buildOptions() {
        const avg = toFloat(feedbackAvg);
        const count = Number.isFinite(Number(feedbackCount)) ? Math.max(0, Number(feedbackCount)) : 0;

        if (avg == null || count <= 0) {
            return {
                graphic: {
                    type: 'text',
                    left: 'center',
                    top: 'middle',
                    style: {
                        text: 'Noch kein Feedback vorhanden',
                        fill: chartTheme.textColor,
                        fontSize: 12
                    }
                }
            };
        }

        const clamped = Math.max(1, Math.min(3, avg));

        return {
            tooltip: {
                trigger: 'item',
                formatter: () => `Durchschnitt: ${clamped.toFixed(2)} (${count} Bewertungen)`,
                backgroundColor: chartTheme.tooltipBackground,
                borderColor: chartTheme.axisLineColor,
                textStyle: { color: chartTheme.textColor }
            },
            series: [{
                type: 'gauge',
                min: 1,
                max: 3,
                splitNumber: 2,
                startAngle: 210,
                endAngle: -30,
                progress: { show: true, width: 14 },
                axisLine: {
                    lineStyle: {
                        width: 14,
                        color: [
                            [0.5, '#ef4444'],
                            [0.75, '#f59e0b'],
                            [1, '#10b981']
                        ]
                    }
                },
                axisTick: { show: false },
                splitLine: { length: 11, lineStyle: { color: chartTheme.axisLineColor } },
                axisLabel: {
                    color: chartTheme.textColor,
                    distance: 20,
                    formatter: (value: number) => {
                        if (value === 1) return '1';
                        if (value === 2) return '2';
                        return '3';
                    }
                },
                pointer: {
                    width: 4,
                    length: '65%'
                },
                detail: {
                    valueAnimation: true,
                    fontSize: 16,
                    color: chartTheme.textColor,
                    offsetCenter: [0, '55%'],
                    formatter: () => `${emojiFor(clamped)} ${clamped.toFixed(2)}`
                },
                data: [{ value: clamped }]
            }],
            graphic: {
                type: 'text',
                left: 'center',
                top: '82%',
                style: {
                    text: `${count} Bewertungen`,
                    fill: chartTheme.textColor,
                    fontSize: 11,
                    textAlign: 'center'
                }
            }
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
            feedbackAvg;
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
    <h5 class="text-xs font-semibold text-on-surface-variant mb-1">{titlePrefix}</h5>
    <div bind:this={chartRef} class="w-full" style="height: 220px;"></div>
</div>

