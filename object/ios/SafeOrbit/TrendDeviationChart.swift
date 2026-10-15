import SwiftUI
import Charts

struct TrendAxisDate: Identifiable, Equatable {
    let id: Int
    let month: String
    let day: String
    var fullLabel: String { "\(month) \(day)" }
    static var samples: [TrendAxisDate] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = DemoRecords.calendar.timeZone
        formatter.dateFormat = "MMM"
        return DemoRecords.weekStarts().enumerated().map { index, date in
            TrendAxisDate(id: index, month: formatter.string(from: date),
                          day: String(DemoRecords.calendar.component(.day, from: date)))
        }
    }
}

struct TrendDeviationChart: View {
    let onLabelsLayout: ((CGSize, [Int: CGRect]) -> Void)?
    init(onLabelsLayout: ((CGSize, [Int: CGRect]) -> Void)? = nil) { self.onLabelsLayout = onLabelsLayout }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    // caregiverText scales relative to body, including its 10-point caption.
    // Reserve the same scaled space as the visible two-line labels.
    @ScaledMetric(relativeTo: .body) private var labelWidth: CGFloat = 23
    @ScaledMetric(relativeTo: .body) private var labelHeight: CGFloat = 26
    @ScaledMetric(relativeTo: .body) private var axisWidth: CGFloat = 24
    private var chartWidth: CGFloat { axisWidth + labelWidth * 8 }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                plot.frame(width: max(geometry.size.width, chartWidth), height: chartHeight)
                    .coordinateSpace(name: "TrendChartSurface")
                    .onPreferenceChange(TrendLabelFrames.self) { frames in
                        onLabelsLayout?(CGSize(width: max(geometry.size.width, chartWidth), height: chartHeight), frames)
                    }
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("trend-chart")
        }
        .frame(height: chartHeight)
    }
    private var chartHeight: CGFloat { (dynamicTypeSize.isAccessibilitySize ? 180 : 108) + labelHeight + 8 }
    private var plot: some View {
        Chart {
            let values = DemoRecords.weeklyDeviations()
            ForEach(values.indices, id: \.self) { index in
                AreaMark(x: .value("Week", index), y: .value("Events", values[index]))
                    .foregroundStyle(LinearGradient(colors: [OrbitStyle.teal.opacity(0.38), .clear],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Week", index), y: .value("Events", values[index]))
                    .foregroundStyle(OrbitStyle.teal).lineStyle(StrokeStyle(lineWidth: 2))
                PointMark(x: .value("Week", index), y: .value("Events", values[index]))
                    .foregroundStyle(OrbitStyle.teal)
                    .accessibilityLabel(TrendAxisDate.samples[index].fullLabel)
                    .accessibilityValue("\(values[index]) events")
            }
        }
        .chartYScale(domain: 0.0...max(3.2, Double(DemoRecords.weeklyDeviations().max() ?? 0)))
        .chartXScale(domain: 0...7, range: .plotDimension(padding: labelWidth / 2 + 2))
        .chartXAxis {
            AxisMarks(values: Array(0...7)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(.gray.opacity(0.2))
                // Reserve space inside the chart canvas; visible labels use plot coordinates.
                AxisValueLabel { Color.clear.frame(width: 1, height: labelHeight + 4) }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 1, 2, 3]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(.gray.opacity(0.2))
                AxisValueLabel {
                    if let number = value.as(Int.self) { Text(verbatim: "\(number)").caregiverText(.caption) }
                }
            }
        }
        .chartLegend(.hidden)
        .frame(height: chartHeight)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let anchor = proxy.plotFrame {
                    let rect = geometry[anchor]
                    ForEach(TrendAxisDate.samples) { date in
                        if let x = proxy.position(forX: date.id) {
                            VStack(spacing: 0) {
                                Text(verbatim: date.month)
                                Text(verbatim: date.day)
                            }
                            .caregiverText(.caption).foregroundStyle(.secondary).fixedSize()
                            .background {
                                GeometryReader { label in
                                    Color.clear.preference(key: TrendLabelFrames.self,
                                        value: [date.id: label.frame(in: .named("TrendChartSurface"))])
                                }
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(date.fullLabel)
                            .accessibilityIdentifier("trend-date-\(date.id)")
                            .position(x: rect.minX + x, y: rect.maxY + labelHeight / 2 + 2)
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }

    }
}

private struct TrendLabelFrames: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
