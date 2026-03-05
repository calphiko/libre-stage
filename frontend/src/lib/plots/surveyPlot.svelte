<script lang="ts">
    import { onMount } from 'svelte';
    import * as echarts from 'echarts/core';
    import { BarChart, PieChart } from 'echarts/charts';
    import { GridComponent, TitleComponent, TooltipComponent, LegendComponent } from 'echarts/components';
    import { CanvasRenderer } from 'echarts/renderers';
    import { isDarkMode } from '$lib/themeStore';

    let { survey, users, fieldColors } = $props();

    echarts.use([BarChart, PieChart, GridComponent, TitleComponent, TooltipComponent, LegendComponent, CanvasRenderer]);

    let barChartRef: HTMLDivElement;
    let donutChartRef: HTMLDivElement;
    let barChart: echarts.ECharts | null = null;
    let donutChart: echarts.ECharts | null = null;

    let chartTheme = $derived({
        backgroundColor: $isDarkMode ? '#1e293b' : '#ffffff',
        textColor: $isDarkMode ? '#e2e8f0' : '#1e293b',
        axisLineColor: $isDarkMode ? '#475569' : '#d1d5db',
        barColor: $isDarkMode ? '#60a5fa' : '#3b82f6',
        successColor: $isDarkMode ? '#34d399' : '#10b981',
        errorColor: $isDarkMode ? '#f87171' : '#ef4444'
    });

    function generatePlotOptionsFromSurvey() {
        const fieldData = survey.fields?.map((field: any, index: number) => ({
            text: field.field_text,
            votes: field.feedbacks?.length || 0,
            color: fieldColors?.[index] ?? chartTheme.barColor,
            label: `${index + 1}. ${field.field_text.slice(0, 25)}${field.field_text.length > 25 ? '…' : ''}`
        })) || [];

        return {
            title: {
                text: 'Umfrageergebnisse',
                left: 'center',
                textStyle: { color: chartTheme.textColor }
            },
            tooltip: {
                trigger: 'axis',
                axisPointer: { type: 'shadow' },
                // Vollständigen Text im Tooltip anzeigen
                formatter: (params: any) => {
                    const idx = params[0].dataIndex;
                    const field = survey.fields?.[idx];
                    return `${field?.field_text ?? ''}: ${params[0].value} Stimme(n)`;
                },
                backgroundColor: $isDarkMode ? '#334155' : '#ffffff',
                borderColor: chartTheme.axisLineColor,
                textStyle: { color: chartTheme.textColor }
            },
            xAxis: {
                type: 'category',
                data: fieldData.map(f => f.label),
                axisLabel: {
                    interval: 0,
                    rotate: 30,
                    color: chartTheme.textColor,
                    fontSize: 12
                },
                axisLine: {
                    lineStyle: { color: chartTheme.axisLineColor }
                }
            },
            yAxis: {
                type: 'value',
                name: 'Anzahl Stimmen',
                minInterval: 1,
                nameTextStyle: { color: chartTheme.textColor },
                axisLabel: { color: chartTheme.textColor },
                axisLine: { lineStyle: { color: chartTheme.axisLineColor } },
                splitLine: { lineStyle: { color: chartTheme.axisLineColor } }
            },
            series: [{
                name: 'Stimmen',
                type: 'bar',
                data: fieldData.map(f => ({
                    value: f.votes,
                    itemStyle: {
                        color: f.color,
                        borderRadius: [4, 4, 0, 0]
                    }
                })),
                label: {
                    show: true,
                    position: 'top',
                    formatter: '{c}',
                    color: chartTheme.textColor
                }
            }]
        };
    }

    function generateDonutChartOptions() {
        const uniqueVoters = new Set();
        survey.fields?.forEach((field: any) => {
            field.feedbacks?.forEach((feedback: any) => {
                uniqueVoters.add(feedback.id_user);
            });
        });

        const votedCount = uniqueVoters.size;
        const totalUsers = users?.length || 0;
        const notVotedCount = totalUsers - votedCount;

        return {
            title: {
                text: 'Teilnahmeübersicht',
                left: 'center',
                textStyle: { color: chartTheme.textColor }
            },
            tooltip: {
                trigger: 'item',
                formatter: '{b}: {c} ({d}%)',
                backgroundColor: $isDarkMode ? '#334155' : '#ffffff',
                borderColor: chartTheme.axisLineColor,
                textStyle: { color: chartTheme.textColor }
            },
            legend: {
                show: false,
                orient: 'vertical',
                left: 'left',
                data: ['Abgegeben', 'Nicht abgegeben'],
                textStyle: { color: chartTheme.textColor }
            },
            series: [{
                name: 'Teilnahme',
                type: 'pie',
                radius: ['45%', '65%'],
                avoidLabelOverlap: false,
                padAngle: 5,
                itemStyle: { borderRadius: 7 },
                label: {
                    show: true,
                    formatter: '{b}: {d}%',
                    color: chartTheme.textColor
                },
                emphasis: {
                    label: { show: true, fontSize: 20, fontWeight: 'bold' }
                },
                data: [
                    { value: votedCount, name: 'Abgegeben', itemStyle: { color: chartTheme.successColor } },
                    { value: notVotedCount, name: 'Nicht abgegeben', itemStyle: { color: chartTheme.errorColor } }
                ]
            }]
        };
    }

    onMount(() => {
        barChart = echarts.init(barChartRef);
        donutChart = echarts.init(donutChartRef);
        barChart.setOption(generatePlotOptionsFromSurvey());
        donutChart.setOption(generateDonutChartOptions());
        return () => { barChart?.dispose(); donutChart?.dispose(); };
    });

    $effect(() => { if (barChart && survey && fieldColors) barChart.setOption(generatePlotOptionsFromSurvey()); });
    $effect(() => { if (donutChart && survey && users) donutChart.setOption(generateDonutChartOptions()); });
    $effect(() => { if (barChart && donutChart && $isDarkMode !== undefined) {
        barChart.setOption(generatePlotOptionsFromSurvey());
        donutChart.setOption(generateDonutChartOptions());
    }});
</script>

<div class="grid grid-cols-1 md:grid-cols-2 gap-4 w-full">
    <div bind:this={barChartRef} class="w-full" style="height:400px;"></div>
    <div bind:this={donutChartRef} class="w-full" style="height:400px;"></div>
</div>