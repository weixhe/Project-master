//
//  CVCalendarLogic.swift
//  Project
//
//  Created by caven on 2018/5/2.
//  Copyright © 2018年 com.caven. All rights reserved.
//

import Foundation
import UIKit

class CVCalendarLogic {

    enum CalendarShowType {
        case single         // 显示单月
        case multiple       // 显示多月
    }
    
    var gregorian: Calendar! = Calendar(identifier: .gregorian)
    
    
//    var model: SomeCalendarProtocol!
    var isDisplayChineseCalender = true
    var isDisplayHoliday = true
    var needsRequestingBoundingDates = true     // 是否需要绑定数据，如果为true，则会重新计算两个日期范围，所包含的月数
    // 日期界限
    var minimumDate: Date = Date.dateFromString("1901-01-01", format: TimeFormat.format_yMd.rawValue)!
    var maximumDate: Date = Date.dateFromString("2099-12-31", format: TimeFormat.format_yMd.rawValue)!
    
    var numberOfMonths: Int = 0
    var numberOfWeeks: Int = 0
    private var months: Dictionary<Int, Date> = [:]     // 保存给个section对应的月份
    private var monthHeads: Dictionary<Int, Date> = [:] // 保存每个月需要展示的第一天的date（可能是这个月的1号，也可能会是上个月的某一天）
    private var rowCounts: Dictionary<Date, Int> = [:]  // 保存每个月分了多少行
    private var days: Dictionary<Int, Int> = [:] // 保存section对用的月份中item对应的所有天
    private var daysForMonth: NSMutableDictionary = NSMutableDictionary()
    deinit {
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidReceiveMemoryWarning, object: nil)
    }
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveMemoryWarning(notify:)), name: .UIApplicationDidReceiveMemoryWarning, object: nil)
    }
    
    
    // MARK: - Notifycation
    /// 通知 - 内存报警
    @objc func didReceiveMemoryWarning(notify: Notification) {
        self.cleanCache()
    }

    /// 计算显示的日历分多少个section，即：有多少个月
    func reloadSections()  {
        numberOfMonths = Date.monthsBetween(from: minimumDate, to: maximumDate)
        numberOfWeeks = Date.weeksBetween(from: minimumDate, to: maximumDate)
        self.cleanCache()
    }
    
    /// 清空缓存，每月，每天的数据
    func cleanCache() {
        self.months.removeAll()
        self.monthHeads.removeAll()
        self.rowCounts.removeAll()
        self.days.removeAll()
    }
    
    /// 绑定数据
    func requestBoundingDatesIfNecessary() {
        if self.needsRequestingBoundingDates {
            self.needsRequestingBoundingDates = false
            // 判断最大和最小日期界限
            let min: Date = Date.dateFromString("1901-01-01", format: TimeFormat.format_yMd.rawValue)!
            let max: Date = Date.dateFromString("2099-12-31", format: TimeFormat.format_yMd.rawValue)!
            if self.minimumDate > min { self.minimumDate = min }
            if self.maximumDate < max { self.maximumDate = max }
            
            self.reloadSections()
        }
    }
    
    /// 判断某个日期是否是安全的，即：在minimumDate 和 maximumDate之间, 如果不在，则适当取最大或最小值
    func safeDateFor(date: Date) -> Date {
        var date = date
        if date.isEarlierToDate(self.minimumDate) {
            date = self.minimumDate
        } else if date.isLaterToDate(self.maximumDate) {
            date = self.maximumDate
        }
        return date.formatDate
    }
    /// 计算每个section中有多少行，即：分别有4、5、6三种行数
    func numberOfRowsInSection(section: Int) -> Int {
        let month = self.monthForSection(section)
        return self.rowCountForMonth(month)
    }
    
    /// 计算每个indexPath中item对应的date
    func dateForIndexPath(_ indexPath: IndexPath) -> Date {
        let monthHead = self.monthHeadForSection(indexPath.section)
        let date = monthHead.addingDays(indexPath.item)
        return date.formatDate
    }
    
    /// 计算date对应的indexPath
    func indexPathForDate(_ date: Date) -> IndexPath {
        let date = self.safeDateFor(date: date) // 取安全的date
        let section = Date.monthsBetween(from: self.minimumDate, to: date) - 1  // 通过两个日期之间的总月份，判定是哪个section
        let row = Date.daysBetween(from: self.monthHeadForSection(section), to: date)
        
        return IndexPath(item: row, section: section)
    }
    
    /// 根据section，查找是哪个月份
    func monthForSection(_ section: Int) -> Date {
        var month = self.months[section]
        if month == nil { // 如果month不存在，则从计算一下当前section的month，并保存起来
            month = self.minimumDate.startOfThisMonth().dayInTheFollowingMonth(section)
            self.months[section] = month!.formatDate
            
            // 计算headMonth
            let numberOfPlaceholders = self.headPlaceholderForMonth(month!)
            let monthHead = month!.addingDays(-numberOfPlaceholders)
            self.monthHeads[section] = monthHead.formatDate
        }
        return month!.formatDate
    }
    
    /// 根据section，计算对应月份的monthHead
    private func monthHeadForSection(_ section: Int) -> Date {
        var monthHead = self.monthHeads[section]
        if monthHead == nil {
            let month = self.minimumDate.startOfThisMonth().dayInTheFollowingMonth(section)
            self.months[section] = month.formatDate
            
            // 计算headMonth
            let numberOfPlaceholders = self.headPlaceholderForMonth(month)
            monthHead = month.addingDays(-numberOfPlaceholders)
            self.monthHeads[section] = monthHead?.formatDate
        }
        return monthHead!
    }
    
    /// 根据month，查找这个月需要多少行才能显示
    func rowCountForMonth(_ month: Date) -> Int {
        var rowCount = self.rowCounts[month]
        if rowCount == nil {    // 如果rowCount不存在，则计算当前section对应的月份的rowCount，并保存起来
            let numOfPlaceholdersForPre = self.headPlaceholderForMonth(month)
            let daysOfMonth = month.daysInThisMonth()   // 这个月有多少天
            let headDayCount = daysOfMonth + numOfPlaceholdersForPre
            rowCount = headDayCount / 7 + (headDayCount % 7 > 0 ? 1 : 0)
            self.rowCounts[month] = rowCount
        }
        return rowCount!
    }
    
    /// 获取每个月1号之前需要显示上个的日期的天数
    private func headPlaceholderForMonth(_ month: Date) -> Int {
        let firstWeekdayOfMonth = month.firstWeeklyInThisMonth() // 这个月的第一天是周几
        let headPlaceholders = (firstWeekdayOfMonth - Date.currentCalendar.firstWeekday + 7) % 7
        return headPlaceholders
    }

    /// 包装日期，变成model, 通过section来确定是那个月份中的日期
    func generalCalendarModel(date: Date, key: String) -> CVCalendarModel {

        var calendar = (self.daysForMonth.object(forKey: key as NSString) as? NSDictionary)?.object(forKey: Date.stringFormDate(date)) as? CVCalendarModel
        if calendar == nil {
            calendar = CVCalendarModel(year: date.year, month: date.month, day: date.day)
            calendar!.isDisplayChineseCalendar = isDisplayChineseCalender   // 默认true
            calendar!.week = date.weekInThisMonth()      // 周几
            
            if isDisplayChineseCalender {       // 是否显示农历
                calendar!.lunar = lunar(date: date)
                let lunar_month_str = lunar_month(date: date)
                let lunar_day_str = lunar_day(date: date)
                calendar!.lunar_year = lunar_year(date: date)
                calendar!.lunar_month = lunar_month_str
                calendar!.lunar_day = lunar_day_str == "初一" ? lunar_month_str : lunar_day_str
            }
            
            calendar!.isDisplayHoliday = isDisplayHoliday   // 默认true
            if isDisplayHoliday {       // 是否显示节日
                calendar!.holiday = [self.solar_holiday(date: date), self.lunar_holiday(date: date), self.twentyFourSolarTerm(date: date)]
                for str in calendar!.holiday! {  // 判断一下，如果是节假日，设置dayType的类型为.holiday
                    if str.count > 0 {
                        calendar!.dayType = .holiday
                        break
                    }
                }
            }
            let value = NSDictionary(object: calendar!, forKey: Date.stringFormDate(date) as NSString)
            self.daysForMonth.setObject(value, forKey: key as NSString)
        }
        if !Date.stringFormDate(date).contains(find: key) {
            calendar!.isEnable = false
        }
        calendar!.dayType = (calendar!.week == 1 || calendar!.week == 7) ? .weekend : .workday  // 周末or工作日

        return calendar!
    }
    
    // MARK: - 获取农历
    func lunar(year: Int, month: Int, day: Int) -> String {
        
        let solar = Solar(year: year, month: month, day: day)
        let lunar = LunarSolarConverter.SolarToLunar(solar: solar)

        // 农历日期名
        let chinese_days = ["*", "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", " 初九", "初十",
                            "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                            "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]

        // 农历月份名
        let chinese_months = ["*", "正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "腊月"]
        if lunar.isleap {
            return "润" + chinese_months[lunar.month] + "-" + chinese_days[lunar.day]
        } else {
            return chinese_months[lunar.month] + "-" + chinese_days[lunar.day]
        }
    }
    
    // MARK: - 以下是系统方法获取农历，据说有问题，但是没发现过
    /// 返回 农历(2017丁酉年闰六月初二星期一)
    func lunar(date: Date) -> String {
        // 设置农历日历
        let chinese = Calendar(identifier: .chinese)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = chinese
        // 日期样式
        formatter.dateStyle = .full
        // 公历转为农历
        let lunar = formatter.string(from: date)
        return lunar
    }
    /// 返回农历的年(丁酉年)
    func lunar_year(date: Date) -> String {
        let chineseYear = ["甲子年", "乙丑年", "丙寅年", "丁卯年", "戊辰年", "己巳年", "庚午年", "辛未年", "壬申年", "癸酉年",
                           "甲戌年", "乙亥年", "丙子年", "丁丑年", "戊寅年", "己卯年", "庚辰年", "辛己年", "壬午年", "癸未年",
                           "甲申年", "乙酉年", "丙戌年", "丁亥年", "戊子年", "己丑年", "庚寅年", "辛卯年", "壬辰年", "癸巳年",
                           "甲午年", "乙未年", "丙申年", "丁酉年", "戊戌年", "己亥年", "庚子年", "辛丑年", "壬寅年", "癸丑年",
                           "甲辰年", "乙巳年", "丙午年", "丁未年", "戊申年", "己酉年", "庚戌年", "辛亥年", "壬子年", "癸丑年",
                           "甲寅年", "乙卯年", "丙辰年", "丁巳年", "戊午年", "己未年", "庚申年", "辛酉年", "壬戌年", "癸亥年"]
        // 设置农历日历
        let chinese = Calendar(identifier: .chinese)
        let componment = chinese.dateComponents([.year], from: date)
        return chineseYear[componment.year! - 1]
    }
    /// 返回农历的月(闰六月)
    func lunar_month(date: Date) -> String {
        let chineseMonth = ["正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月",
                            "九月", "十月", "十一月", "腊月"]
        // 设置农历日历
        let chinese = Calendar(identifier: .chinese)
        let componment = chinese.dateComponents([.year, .month], from: date)
        if let isLeap = componment.isLeapMonth, isLeap == true {
            return "润" + chineseMonth[componment.month! - 1]
        }
        return chineseMonth[componment.month! - 1]
    }
    /// 返回农历的日(初二)
    func lunar_day(date: Date) -> String {
        let chineseDay = ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                          "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                          "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]
        // 设置农历日历
        let chinese = Calendar(identifier: .chinese)
        let componment = chinese.dateComponents([.year, .month, .day], from: date)
        return chineseDay[componment.day! - 1]
    }
    
    // MARK: - 计算节日、节气
    func lunar_holiday(date: Date) -> String {
        let lunar_month = self.lunar_month(date: date)
        let lunar_day = self.lunar_day(date: date)
        var result = ""
        
        // 除夕单独计算，春节的前一天
        if self.lunar_month(date: date.addingDays(-1)) == "正月" && self.lunar_day(date: date.addingDays(-1)) == "初一" {
            result = "除夕"
        } else if lunar_month == "正月" && lunar_day == "初一" {
            result = "春节"
        } else if lunar_month == "正月" && lunar_day == "十五" {
            result = "元宵节"
        } else if lunar_month == "二月" && lunar_day == "初二" {
            result = "龙抬头"
        } else if lunar_month == "五月" && lunar_day == "初五" {
            result = "端午节"
        } else if lunar_month == "七月" && lunar_day == "初七" {
            result = "七夕节"
        } else if lunar_month == "八月" && lunar_day == "十五" {
            result = "中秋节"
        } else if lunar_month == "九月" && lunar_day == "初九" {
            result = "重阳节"
        } else if lunar_month == "腊月" && lunar_day == "初八" {
            result = "腊八节"
        } else if lunar_month == "腊月" && lunar_day == "廿三" {
            result = "北方小年"
        } else if lunar_month == "腊月" && lunar_day == "廿四" {
            result = "南方小年"
        }
        return result
    }
    
    /// 公历节日
    func solar_holiday(date: Date) -> String {
        var result = ""
        if date.month == 1 && date.day == 1 {
            result = "元旦"
        } else if date.month == 2 && date.day == 14 {
            result = "情人节"
        } else if date.month == 3 && date.day == 8 {
            result = "妇女节"
        } else if date.month == 3 && date.day == 12 {
            result = "植树节"
        } else if date.month == 5 && date.day == 1 {
            result = "劳动节"
        } else if date.month == 6 && date.day == 1 {
            result = "儿童节"
        } else if date.month == 8 && date.day == 1 {
            result = "建军节"
        } else if date.month == 9 && date.day == 10 {
            result = "教师节"
        } else if date.month == 10 && date.day == 1 {
            result = "国庆节"
        } else if date.month == 11 && date.day == 11 {
            result = "光棍节"
        } else if date.month == 12 && date.day == 25 {
            result = "圣诞节"
        }
        return result
    }
    
    /// 二十四节气
    func twentyFourSolarTerm(date: Date) -> String {
        // 24节气只有(1901 - 2050)之间为准确的节气
        
        /*  定气法计算二十四节气,二十四节气是按地球公转来计算的，并非是阴历计算的
         
            节气的定法有两种。古代历法采用的称为"恒气"，即按时间把一年等分为24份，
            每一节气平均得15天有余，所以又称"平气"。现代农历采用的称为"定气"，即
            按地球在轨道上的位置为标准，一周360°，两节气之间相隔15°。由于冬至时地
            球位于近日点附近，运动速度较快，因而太阳在黄道上移动15°的时间不到15天。
            夏至前后的情况正好相反，太阳在黄道上移动较慢，一个节气达16天之多。采用
            定气时可以保证春、秋两分必然在昼夜平分的那两天。
         */
        let solarTerm = ["小寒", "大寒", "立春", "雨水", "惊蛰", "春分", "清明", "谷雨", "立夏", "小满", "芒种", "夏至", "小暑", "大暑", "立秋", "处暑", "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"]
        let solarTermInfo = [0, 21208, 42467, 63836, 85337, 107014, 128867, 150921, 173149, 195551, 218072, 240693, 263343, 285989, 308563, 331033, 353350, 375494, 397447, 419210, 440795, 462224, 483532, 504758]
        
        let baseDateAndTime = Date.dateFromString("1900-01-06 02:05:00", format: "yyyy-HH-dd HH:mm:ss")!
        var newDate: Date!
        var num = 0.0
        var result = ""
        let year = date.year        // ??? 确定这里不需要换算成农历后在进行计算比较？？
        for i in 1...24 {
            num = 525948.76 * Double(year - 1900) + Double(solarTermInfo[i - 1])
            newDate = baseDateAndTime.addingTimeInterval(num * 60) // 按分钟计算
            if newDate.month == date.month && newDate.day == date.day {
                result = solarTerm[i - 1];
                break;
            }
        }
        
        return result
    }
    
    // MARK: - 星座 & 属相
    func constellationName(date: Date) -> String {
        let constellations = ["白羊座", "金牛座", "双子座", "巨蟹座", "狮子座", "处女座", "天秤座", "天蝎座", "射手座", "摩羯座", "水瓶座", "双鱼座"]
        var index = 0;
        let year = date.month * 100 + date.day;
        
        if (((year >= 321) && (year <= 419))) { index = 0 }
        else if ((year >= 420) && (year <= 520)) { index = 1 }
        else if ((year >= 521) && (year <= 620)) { index = 2 }
        else if ((year >= 621) && (year <= 722)) { index = 3 }
        else if ((year >= 723) && (year <= 822)) { index = 4 }
        else if ((year >= 823) && (year <= 922)) { index = 5 }
        else if ((year >= 923) && (year <= 1022)) { index = 6 }
        else if ((year >= 1023) && (year <= 1121)) { index = 7 }
        else if ((year >= 1122) && (year <= 1221)) { index = 8 }
        else if ((year >= 1222) || (year <= 119)) { index = 9 }
        else if ((year >= 120) && (year <= 218)) { index = 10 }
        else if ((year >= 219) && (year <= 320)) { index = 11 }
        else { index = 0 }
        
        return constellations[index];
    }
    
    func animal(date: Date) -> String {
        let animalStartYear = 1900 // 1900年为鼠年
        let offset = date.year - animalStartYear
        return "鼠牛虎兔龙蛇马羊猴鸡狗猪".subString(range: NSMakeRange(abs(offset) % 12, 1))
    }
    
    // MARK: - 天干地支
    /// 取农历天干地支表示年月日（甲子年乙丑月丙庚日）
    func gan_zhi(date: Date) -> String {
        return self.gan_zhi_year(date: date) + self.gan_zhi_month(date: date) + self.gan_zhi_day(date: date)
    }
    
    /// 取农历年的干支表示法（乙丑年）
    func gan_zhi_year(date: Date) -> String {
        let ganZhiStartYear = 1864 // 干支计算起始年
        // 换算农历日历
        let solar = Solar(year: date.year, month: date.month, day: date.day)
        let lunar = LunarSolarConverter.SolarToLunar(solar: solar)
        let i: Int = (lunar.year - ganZhiStartYear) % 60 //计算干支
        let gan = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"][abs(i) % 10]
        let zhi = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"][abs(i) % 12]
        return gan + zhi + "年"
    }
    
    /// 取干支的月表示字符串（乙丑月），注意农历的闰月不记干支
    func gan_zhi_month(date: Date) -> String {
        var zhiIndex: Int!
        // 换算农历日历
        let solar = Solar(year: date.year, month: date.month, day: date.day)
        let lunar = LunarSolarConverter.SolarToLunar(solar: solar)
        if (lunar.month > 10) {  // 每个月的地支总是固定的, 而且总是从寅月开始
            zhiIndex = lunar.month - 10
        } else {
            zhiIndex = lunar.month + 2
        }
        let zhi = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"][zhiIndex - 1]
        
        // 根据当年的干支年的干来计算月干的第一个
        var ganIndex = 1;
        let ganZhiStartYear = 1864 // 干支计算起始年
        let i = (lunar.year - ganZhiStartYear) % 60; // 计算干支
        switch (i % 10) {
        case 0: // 甲
            ganIndex = 3
        case 1: // 乙
            ganIndex = 5
        case 2: // 丙
            ganIndex = 7
        case 3: // 丁
            ganIndex = 9
        case 4: // 戊
            ganIndex = 1
        case 5: // 己
            ganIndex = 3
        case 6: // 庚
            ganIndex = 5
        case 7: // 辛
            ganIndex = 7
        case 8: // 壬
            ganIndex = 9
        case 9: // 癸
            ganIndex = 1
        default:
            ganIndex = 1
        }
        let gan = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"][(ganIndex + lunar.month - 2) % 10]
        
        return gan + zhi + "月";
    }
    
    /// 取干支日表示法（丙庚日）
    func gan_zhi_day(date: Date) -> String {
        // 换算农历日历
        let solar = Solar(year: date.year, month: date.month, day: date.day)
        let lunar = LunarSolarConverter.SolarToLunar(solar: solar)
        let dateString = String.init(format: "%d-%d-%d %d:%d:%d", lunar.year, lunar.month, lunar.day, date.hour, date.minute, date.second)
        let lunar1 = Date.dateFromString(dateString, format: "yyyy-MM-dd HH:mm:ss")
        let i: Int = lunar1!.daysBetweenDate(Date.dateFromString("1899-12-22")!) % 60
        let gan = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"][abs(i) % 10]
        let zhi = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"][abs(i) % 12]
        return gan + zhi + "日"
    }
}

fileprivate extension Date {
    /// 格式化date，使其不受time和地域的影响
    var formatDate: Date {
        return Date.dateFromString(Date.stringFormDate(self))!
    }
}
