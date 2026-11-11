import SwiftUI
import CampusCore

private enum PortalSheet: String, Identifiable { case portal; var id: String { rawValue } }
enum Palette {
    static let forest = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.63, green: 0.83, blue: 0.69, alpha: 1) : UIColor(red: 0.12, green: 0.34, blue: 0.25, alpha: 1)
    })
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let background = Color(uiColor: .systemGroupedBackground)
}

struct RootView: View {
    @EnvironmentObject var store: CampusStore
    @State private var selectedTab = ProcessInfo.processInfo.arguments.contains("--preview-search") ? 4 : (ProcessInfo.processInfo.arguments.contains("--preview-exams") ? 2 : 0)
    @State private var searchText = ""
    var body: some View {
        Group {
            if store.mode == .login { LoginView() }
            else if #available(iOS 26.0, *) {
                TabView(selection: $selectedTab) {
                    Tab("课表", systemImage: "calendar", value: 0) { ScheduleHome() }
                    Tab("成绩", systemImage: "chart.bar.xaxis", value: 1) { RecordsView(feature: .grades) }
                    Tab("考试", systemImage: "pencil.and.list.clipboard", value: 2) { RecordsView(feature: .exams) }
                    Tab("我的", systemImage: "person.crop.circle", value: 3) { AccountView() }
                    Tab("搜索", systemImage: "magnifyingglass", value: 4, role: .search) {
                        UniversalSearchView(query: $searchText, selectTab: { selectedTab = $0 })
                            .searchable(text: $searchText, prompt: "搜索功能、课程和信息")
                    }
                }
                .tabViewSearchActivation(.searchTabSelection)
                .tabBarMinimizeBehavior(.onScrollDown)
                .onOpenURL { url in if url.scheme == "lanke", url.host == "timetable" { selectedTab = 0 } }
            } else {
                TabView(selection: $selectedTab) {
                    ScheduleHome().tag(0).tabItem { Label("课表", systemImage: "calendar") }
                    RecordsView(feature: .grades).tag(1).tabItem { Label("成绩", systemImage: "chart.bar.xaxis") }
                    RecordsView(feature: .exams).tag(2).tabItem { Label("考试", systemImage: "pencil.and.list.clipboard") }
                    AccountView().tag(3).tabItem { Label("我的", systemImage: "person.crop.circle") }
                    UniversalSearchView(query: $searchText, selectTab: { selectedTab = $0 }).searchable(text: $searchText, prompt: "搜索功能、课程和信息")
                        .tag(4).tabItem { Label("搜索", systemImage: "magnifyingglass") }
                }
            }
        }
    }
}

struct LoginView: View {
    @EnvironmentObject var store: CampusStore
    @State private var account = ""
    @State private var password = ""
    @State private var captcha = ""
    @State private var portal: PortalSheet?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "leaf.fill").font(.system(size: 42)).foregroundStyle(Palette.forest)
                        Text("览课").font(.system(size: 36, weight: .bold, design: .rounded))
                    }.padding(.top, 28)
                    VStack(spacing: 18) {
                        if !store.savedAccounts.isEmpty {
                            Menu("切换已保存账号") {
                                ForEach(store.savedAccounts, id: \.account) { saved in
                                    Button(saved.account) { account = saved.account; password = saved.password; captcha = "" }
                                }
                            }
                        }
                        TextField("学号", text: $account).textContentType(.username).keyboardType(.asciiCapable)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .accessibilityIdentifier("account")
                        Divider()
                        SecureField("教务系统密码", text: $password).textContentType(.password)
                            .accessibilityIdentifier("password")
                        Divider()
                        HStack(spacing: 12) {
                            TextField("验证码", text: $captcha).textInputAutocapitalization(.never)
                                .autocorrectionDisabled().keyboardType(.asciiCapable)
                                .accessibilityIdentifier("captcha")
                            Button {
                                captcha = ""
                                Task { await store.refreshCaptcha() }
                            } label: {
                                if let image = store.captchaImage {
                                    Image(uiImage: image).resizable().interpolation(.none)
                                        .scaledToFit().frame(width: 112, height: 44)
                                } else { Text("获取验证码").font(.callout).frame(minHeight: 44) }
                            }.accessibilityLabel("获取或更换验证码")
                        }
                    }.padding(22).background(Palette.card, in: RoundedRectangle(cornerRadius: 22))
                    VStack(spacing: 12) {
                        Button {
                            let secret = password
                            // Keep input after an unsuccessful login.
                            Task { await store.login(account: account.trimmingCharacters(in: .whitespacesAndNewlines),
                                                     password: secret, captcha: captcha.trimmingCharacters(in: .whitespacesAndNewlines)) }
                        } label: {
                            HStack { if store.busy { ProgressView().tint(.white) }; Text(store.busy ? "正在连接…" : "登录教务系统").fontWeight(.semibold) }
                                .frame(maxWidth: .infinity).padding(.vertical, 9)
                        }.modifier(LankePrimaryButton()).controlSize(.large)
                            .disabled(store.busy || account.isEmpty || password.isEmpty || captcha.isEmpty || store.captchaImage == nil)
                        Toggle("记住密码并自动登录", isOn: Binding(get: { store.rememberLogin }, set: { store.setRememberLogin($0) }))
                        Text("学校入口使用 HTTP。会话保存在本机钥匙串；成功登录的账号和密码保存在本机钥匙串，可切换账号；自动登录由开关控制。验证码无法识别时需手动输入。")
                            .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let cached = store.cachedStudent {
                        Button { store.openOffline() } label: { Label("离线查看 \(cached.name) 的已下载数据", systemImage: "internaldrive") }
                    }
                    HStack {
                        Button("先体验界面") { store.openDemo() }
                        Spacer()
                        Button("教务原网页") { portal = .portal }
                    }.font(.callout)
                }.padding(24).disabled(store.busy)
            }
            .background(Palette.background)
            .onAppear {
                if let remembered = store.rememberedCredentials, account.isEmpty {
                    account = remembered.account; password = remembered.password
                }
            }
            .sheet(item: $portal) { _ in SchoolPortalView() }
        }
    }
}

struct StatusStrip: View {
    @EnvironmentObject var store: CampusStore
    let date: Date?
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text(date.map { SchoolSchedule.updateAge($0, now: context.date) } ?? "尚未获取")
                .font(.caption).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct PageHeading: View {
    let title: String
    let date: Date?
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline).lineLimit(1)
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(date.map { SchoolSchedule.updateAge($0, now: context.date) } ?? "尚未获取")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }.fixedSize(horizontal: true, vertical: false).accessibilityElement(children: .combine)
    }
}

struct PageHeadingToolbar: ToolbarContent {
    let title: String
    let date: Date?
    @ToolbarContentBuilder var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) { PageHeading(title: title, date: date) }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) { PageHeading(title: title, date: date) }
        }
    }
}

struct SemesterControls: View {
    let options: PageOptions
    let disabled: Bool
    var recordCount: Int? = nil
    let query: (Semester) -> Void
    @State private var year = ""
    @State private var term = ""
    var body: some View {
        if !options.years.isEmpty && !options.terms.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Menu {
                        ForEach(options.years) { option in
                            Button { year = option.value } label: {
                                if option.value == year {
                                    Label(option.label, systemImage: "checkmark")
                                } else {
                                    Text(option.label)
                                }
                            }
                        }
                    } label: { Text(year.split(separator: "-").map { String($0.suffix(2)) }.joined(separator: "–") + "⌄") }.fixedSize(horizontal: true, vertical: false)
                    Picker("学期", selection: $term) { ForEach(options.terms) { Text("第\($0.label)学期").tag($0.value) } }.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    if let recordCount { Text("\(recordCount) 条记录").font(.caption).foregroundStyle(.secondary) }
                    Button("查询") { query(Semester(year: year, term: term)) }
                        .disabled(disabled || year.isEmpty || term.isEmpty)
                }.pickerStyle(.menu).font(.subheadline).lineLimit(1).minimumScaleFactor(0.75)
            }
            .task(id: options.selected.title) { year = options.selected.year; term = options.selected.term }
        }
    }
}

struct EmptyPanel: View {
    let title: String
    let detail: String
    var body: some View {
        ContentUnavailableView { Label(title, systemImage: "leaf") } description: { Text(detail) }
            .frame(minHeight: 220)
    }
}

struct RecordsView: View {
    @EnvironmentObject var store: CampusStore
    let feature: CampusStore.Feature
    @State private var showSearch = false
    @State private var ascending = true
    private let search = ""
    @State private var year = "全部"
    @State private var term = "全部"
    private var report: RecordsReport? { feature == .grades ? store.snapshot?.grades : store.snapshot?.exams }
    private var allRecords: [TableRecord] { report?.records ?? [] }
    private var years: [String] { Array(Set(allRecords.map { $0.value(["学年"]) }.filter { !$0.isEmpty })).sorted(by: >) }
    private var terms: [String] { Array(Set(allRecords.map { $0.value(["学期"]) }.filter { !$0.isEmpty })).sorted() }
    private var filtered: [TableRecord] {
        let records = allRecords.filter {
            (search.isEmpty || $0.fields.contains { $0.value.localizedCaseInsensitiveContains(search) })
            && (feature != .grades || year == "全部" || $0.value(["学年"]) == year)
            && (feature != .grades || term == "全部" || $0.value(["学期"]) == term)
        }
        return RecordOrdering.sorted(records, byScore: feature == .grades, ascending: ascending)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if store.needsLogin {
                        Button("重新登录以更新数据") { Task { await store.requestLogin() } }.disabled(store.busy)
                    } else if store.hasSavedSession && !store.isOnline {
                        Button("恢复连接") { Task { await store.restoreConnection() } }.disabled(store.busy)
                    }
                    if feature == .exams, let report {
                        SemesterControls(options: report.options, disabled: !store.isOnline || store.busy, recordCount: filtered.count) { semester in
                            Task { await store.refresh(.exams, semester: semester) }
                        }
                    }
                    if feature == .grades && !years.isEmpty {
                        HStack {
                            Picker("学年", selection: $year) {
                                Text("全部学年").tag("全部")
                                ForEach(years, id: \.self) { Text($0).tag($0) }
                            }
                            Picker("学期", selection: $term) {
                                Text("全部学期").tag("全部")
                                ForEach(terms, id: \.self) { Text("第\($0)学期").tag($0) }
                            }
                            Spacer(minLength: 0)
                            Text("\(filtered.count) 条记录").font(.caption).foregroundStyle(.secondary)
                        }.pickerStyle(.menu)
                    }
                    if report == nil {
                        EmptyPanel(title: "还没有\(feature.rawValue)数据", detail: "登录后点击刷新获取，查询失败不会覆盖之前的记录。")
                    } else if filtered.isEmpty {
                        EmptyPanel(title: "暂无符合条件的记录", detail: search.isEmpty ? "学校页面当前未列出相应记录。" : "试试其他关键词。")
                    } else {
                        ForEach(filtered) { record in
                            NavigationLink { RecordDetailView(record: record) } label: {
                                HStack(alignment: .top, spacing: 16) {
                                    VStack(alignment: .leading, spacing: 9) {
                                        Text(record.title).font(.headline).foregroundStyle(.primary)
                                        if feature == .grades {
                                            Text("学分 \(record.value(["学分"])) · \(record.value(["课程性质"]))")
                                                .font(.caption).foregroundStyle(.secondary)
                                        } else {
                                            Text(record.value(["考试时间", "时间"])).font(.callout).foregroundStyle(.secondary)
                                            Text(record.value(["考试地点", "考试教室", "地点"])).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                    if feature == .grades {
                                        Text(record.value(["成绩", "总评成绩"]))
                                            .font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(gradeColor(record.value(["成绩", "总评成绩"])))
                                    }
                                    if feature == .exams {
                                        TimelineView(.periodic(from: .now, by: 60)) { context in
                                            Text(ScheduledExam(record: record)?.countdown(at: context.date) ?? "时间待定")
                                                .font(.caption.weight(.semibold)).foregroundStyle(Palette.forest)
                                                .multilineTextAlignment(.trailing).frame(width: 90, alignment: .trailing)
                                        }
                                    }
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                }.padding(20).background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(20)
            }
            .background(Palette.background).navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSearch) { RecordsSearchView(records: filtered, title: feature.rawValue) }
            .toolbar {
                PageHeadingToolbar(title: feature == .grades ? "我的成绩" : "考试安排", date: report?.fetchedAt)
                ToolbarItem(placement: .topBarTrailing) {
                    Button { ascending.toggle() } label: {
                        Image(systemName: ascending ? "arrow.up" : "arrow.down")
                    }.accessibilityLabel((feature == .grades ? "分数" : "考试时间") + (ascending ? "升序，点击改为降序" : "降序，点击改为升序"))
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showSearch = true } label: { Image(systemName: "magnifyingglass") }
                        .accessibilityLabel("搜索\(feature.rawValue)")
                    Button { Task { await store.refresh(feature, semester: feature == .exams ? report?.options.selected : nil) } }
                    label: { Image(systemName: "arrow.clockwise") }
                        .disabled(store.busy || !store.isOnline).accessibilityLabel("刷新\(feature.rawValue)")
                }
            }
            .safeAreaInset(edge: .top) { if store.busy { ProgressView("正在查询学校数据…").font(.caption).padding(8).frame(maxWidth: .infinity).background(.regularMaterial) } }
        }
    }
}

private func gradeColor(_ text: String) -> Color {
    guard let grade = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return Palette.forest }
    if grade < 60 { return .red }
    if grade >= 90 { return Palette.forest }
    if grade >= 80 { return LessonColors.soon }
    if grade >= 70 { return .purple }
    return .blue
}

struct RecordDetailView: View {
    let record: TableRecord
    var body: some View {
        List {
            ForEach(Array(record.fields.enumerated()), id: \.offset) { _, field in
                VStack(alignment: .leading, spacing: 8) {
                    Text(field.label.isEmpty ? "其他信息" : field.label).font(.caption).foregroundStyle(.secondary)
                    Text(field.value.isEmpty ? "—" : field.value).textSelection(.enabled)
                }.padding(.vertical, 4)
            }
        }.navigationTitle(record.title).navigationBarTitleDisplayMode(.inline)
    }
}

struct AccountView: View {
    @EnvironmentObject var store: CampusStore
    @State private var portal: PortalSheet?
    @EnvironmentObject var planner: Planner
    @State private var confirmClear = false
    @EnvironmentObject var activities: LessonActivityManager
    @AppStorage("lanke.live.enabled.v2") private var liveEnabled = true
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(store.snapshot?.student.name ?? "同学").font(.title2.bold())
                            Text(store.snapshot?.student.account ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "person.crop.circle.fill").font(.largeTitle).foregroundStyle(Palette.forest) }
                    LabeledContent("当前状态", value: store.badge)
                }
                Section {
                    NavigationLink("课表设置") { ScheduleSettings() }
                    NavigationLink("学分（选修）查询") { ElectiveCreditsView() }
                    Toggle("记住密码并自动登录", isOn: Binding(get: { store.rememberLogin }, set: { store.setRememberLogin($0) }))
                }
                Section("校园网") {
                    Link("教室校园网登录", destination: URL(string: "http://10.8.30.1")!)
                    Link("宿舍校园网登录", destination: URL(string: "http://210.34.84.127")!)
                }
                Section("查询与数据") {
                    Button("刷新实时活动") {
                        liveEnabled = true
                        Task {
                            await activities.refresh(exams: store.snapshot?.exams?.records ?? [], lessons: planner.activityLessons(account: store.snapshot?.student.account ?? "", report: store.snapshot?.timetable, on: .now), account: store.snapshot?.student.account ?? "", enabled: store.mode != .demo && store.mode != .login)
                            store.message = activities.message ?? "已重新预约当天最近的课程实时活动。"
                        }
                    }
                    Button("刷新全部数据") { Task { await store.refreshAll() } }.disabled(store.busy || !store.isOnline)
                    if store.hasSavedSession && !store.isOnline {
                        Button("恢复连接") { Task { await store.restoreConnection() } }.disabled(store.busy)
                    }
                    Button("教务原网页") { portal = .portal }
                    Button(store.mode == .demo ? "退出示例，登录学校账号" : "返回登录（保留离线数据）") {
                        Task { await store.returnToLogin() }
                    }.disabled(store.busy)
                    Button("清除本地数据并退出", role: .destructive) { confirmClear = true }.disabled(store.busy)
                }
                Section {
                    NavigationLink { AboutView() } label: {
                        Label("关于览课", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("我的")
            .sheet(item: $portal) { _ in SchoolPortalView() }
            .confirmationDialog("清除这台设备上保存的课表、成绩和考试记录？", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("清除并退出", role: .destructive) { Task { planner.clear(); await store.clearAndSignOut() } }
                Button("取消", role: .cancel) {}
            }
        }
    }
}

private struct LankePrimaryButton: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}

struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }
    var body: some View {
        List {
            Section {
                Text("版本 \(version)")
            }
            Section("关于应用") {
                Text("非学校官方应用。数据来自你登录后的教务网页；课表、成绩与考试安排在本机解析。")
            }
            Section("登录与数据") {
                Text("登录会话保存在本机钥匙串。关闭应用后会自动恢复并向学校验证；会话失效时需要重新输入验证码登录。成功登录的账号密码保存在本机钥匙串，清除本地数据时移除。")
                Text("学校入口使用 HTTP。已下载的记录保存在本机，不包含密码或网页原文。退出登录会移除已保存的会话。")
                Text("多任务界面正常显示当前页面。")
            }
            Section("课表说明") {
                Text("课表按学期展示，单双周与调停课请以学校原始说明为准。数据通过手动刷新更新，不提供后台实时推送。")
            }
        }
        .navigationTitle("关于览课")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RecordsSearchView: View {
    let records: [TableRecord]
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    private var results: [TableRecord] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return records.filter { keyword.isEmpty || $0.fields.contains { $0.value.localizedCaseInsensitiveContains(keyword) } }
    }
    var body: some View {
        NavigationStack {
            List {
                ForEach(results) { record in
                    NavigationLink(record.title) { RecordDetailView(record: record) }
                }
            }
            .overlay { if results.isEmpty { ContentUnavailableView.search(text: query) } }
            .navigationTitle("搜索" + title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索课程或其他信息")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

struct ElectiveCreditsView: View {
    @EnvironmentObject var store: CampusStore
    var body: some View {
        List {
            if let report = store.snapshot?.electives {
                Section { Text(SchoolSchedule.updateAge(report.fetchedAt, now: .now)).font(.caption).foregroundStyle(.secondary) }
                ForEach(report.records) { record in
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(record.fields.enumerated()), id: \.offset) { _, field in
                            LabeledContent(field.label, value: field.value.isEmpty ? "—" : field.value)
                        }
                    }.padding(.vertical, 8)
                }
                Section { Text("以上为学校培养计划页面的原始统计；培养要求以学校发布内容为准。").font(.footnote).foregroundStyle(.secondary) }
            } else {
                Text(store.mode == .demo ? "示例模式不提供学分统计，请登录后查询。" : "尚未查询选修学分。")
            }
        }.navigationTitle("学分（选修）").navigationBarTitleDisplayMode(.inline)
            .overlay { if store.busy { ProgressView() } }
            .toolbar { Button { Task { await store.refreshElectives() } } label: { Image(systemName: "arrow.clockwise") }.disabled(store.busy || !store.isOnline) }
            .task { if store.snapshot?.electives == nil { await store.refreshElectives() } }
    }
}

struct UniversalSearchView: View {
    @Binding var query: String
    let selectTab: (Int) -> Void
    @EnvironmentObject private var store: CampusStore
    @EnvironmentObject private var planner: Planner
    @State private var showPortal = false
    @State private var addingLesson = false
    private var results: [AppSearchEntry] {
        AppSearchIndex.entries(snapshot: store.snapshot, manual: planner.saved.manual, hidden: planner.saved.hidden)
            .filter { $0.matches(query) }
    }
    private var hasQuery: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var body: some View {
        NavigationStack {
            List {
                if !hasQuery {
                    Section {
                        Text("搜索应用功能、已下载的课表、成绩、考试、选修学分与手动课程。未下载的信息请先在对应页面查询。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                ForEach(["功能", "个人信息", "课表", "手动课程", "成绩", "考试", "选修学分", "调停课说明"], id: \.self) { category in
                    let items = results.filter { $0.category == category && (hasQuery || category == "功能") }
                    if !items.isEmpty {
                        Section(category) {
                            ForEach(items) { item in
                                if let tab = ["schedule": 0, "grades": 1, "exams": 2, "account": 3][item.route] {
                                    Button { selectTab(tab) } label: { resultLabel(item) }
                                } else if item.route == "portal" {
                                    Button { showPortal = true } label: { resultLabel(item) }
                                } else if item.route == "add" {
                                    Button { addingLesson = true } label: { resultLabel(item) }
                                } else {
                                    NavigationLink { destination(item) } label: { resultLabel(item) }
                                }
                            }
                        }
                    }
                }
            }
            .overlay { if hasQuery && results.isEmpty { ContentUnavailableView.search(text: query) } }
            .navigationTitle("搜索")
            .sheet(isPresented: $showPortal) { SchoolPortalView() }
            .sheet(isPresented: $addingLesson) { AddLessonView(day: .now) }
            .task(id: store.snapshot?.student.account) { planner.load(account: store.snapshot?.student.account ?? "") }
        }
    }
    private func resultLabel(_ item: AppSearchEntry) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.title).foregroundStyle(.primary)
            if !item.subtitle.isEmpty { Text(item.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
        }.padding(.vertical, 3)
    }
    @ViewBuilder private func destination(_ item: AppSearchEntry) -> some View {
        switch item.route {
        case "schedule": ScheduleHome()
        case "grades": RecordsView(feature: .grades)
        case "exams": RecordsView(feature: .exams)
        case "settings": ScheduleSettings()
        case "electives": ElectiveCreditsView()
        case "about": AboutView()
        case "account": AccountView()
        case "manual":
            if let lesson = planner.saved.manual.first(where: { "manual-" + $0.id == item.id }) {
                LessonDetail(lesson: lesson)
            } else { Text("课程已移除") }
        default: RecordDetailView(record: TableRecord(id: item.id, fields: item.fields))
        }
    }
}
