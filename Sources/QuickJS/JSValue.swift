// QuickJS Swift
//
// Copyright (c) 2021 zqqf16
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import QuickJSC

public typealias JSCValue = QuickJSC.JSValue
public typealias JSCValuePointer = UnsafeMutablePointer<JSCValue>

// MARK: - JSValue

extension JSCValue {
    static var null: JSCValue {
        return JSCValue(u: JSValueUnion(int32: 0), tag: Int64(JS_TAG_NULL))
    }
    
    static var undefined: JSCValue {
        return JSCValue(u: JSValueUnion(int32: 0), tag: Int64(JS_TAG_UNDEFINED))
    }
}

public class JSValue {
    var cValue: JSCValue
    var context: JSContextWrapper?
    var autoFree: Bool = true

    required init(_ context: JSContextWrapper?, value: JSCValue, dup: Bool = false, autoFree: Bool = true) {
        self.context = context
        if dup {
            self.cValue = self.context!.dup(value)
        }
        self.cValue = value
        self.autoFree = autoFree
    }
    
    public convenience init(_ context: JSContext, value: JSCValue, dup: Bool = false, autoFree: Bool = true) {
        self.init(context.core, value: value, dup: dup, autoFree: autoFree)
    }
    
    func setOpaque<T: AnyObject>(_ obj: T) {
        let ptr = Unmanaged<T>.passUnretained(obj).toOpaque()
        JS_SetOpaque(cValue, ptr)
    }
    
    func getOpaque<T: AnyObject>() -> T? {
        if let ptr = JS_GetOpaque(cValue, 1) {
            return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
        }
        return nil
    }
    
    deinit {
        if autoFree {
            context?.free(cValue)
        }
    }
}

extension JSValue {
    public static var undefined: JSValue {
        return JSValue(nil, value: .undefined)
    }
    public static var null: JSValue {
        return JSValue(nil, value: .null)
    }
}

extension JSValue {
    public var isFunction: Bool {
        guard let context = context?.context else { return false }
        return JS_IsFunction(context, cValue) != 0
    }
    
    public var isException: Bool {
        return JS_IsException(cValue) != 0
    }
    
    public var isObject: Bool {
        return JS_IsObject(cValue) != 0
    }
    
    public var isNull: Bool {
        return JS_IsNull(cValue) != 0
    }
    
    public var isString: Bool {
        return JS_IsString(cValue) != 0
    }
    
    public var isUndefined: Bool {
        return JS_IsUndefined(cValue) != 0
    }
    
    public var isArray: Bool {
        guard let context = context?.context else { return false }
        return JS_IsArray(context, cValue) != 0
    }
    
    public var isBoolean: Bool {
        return JS_IsBool(cValue) != 0
    }
    
    public var isNumber: Bool {
        return JS_IsNumber(cValue) != 0
    }
    
    public var isSymbol: Bool {
        return JS_IsSymbol(cValue) != 0
    }
    
    public var isBigInt: Bool {
        guard let context = context?.context else { return false }
        return JS_IsBigInt(context, cValue) != 0
    }
    
    public var isBool: Bool {
        return JS_IsBool(cValue) != 0
    }
    
    public func getValue<T:ConvertibleWithJavascript>() -> T? {
        return context != nil ? T(context!, value: cValue) : nil
    }
    
    public func toDouble() -> Double? {
        guard self.context != nil else { return nil }
        return self.getValue()
    }
    
    public func toInt() -> Int? {
        guard self.context != nil else { return nil }
        return self.getValue()
    }
    
    public func toString() -> String? {
        guard self.context != nil else { return nil }
        return self.getValue()
    }
    
    public func toBool() -> Bool? {
        guard self.context != nil else { return nil }
        return self.getValue()
    }
    
    public func toError() -> JSError? {
        guard self.context != nil else { return nil }
        return self.getValue()
    }
}

// MARK: function
extension JSValue {
    private func call(withArguments: [JSValue]) -> JSValue! {
        guard let wrapper = context, JS_IsFunction(wrapper.context, cValue) == 1 else {
            return .undefined
        }
        let arguments = withArguments
        let argc = Int32(arguments.count)
        var argv = arguments.map{ $0.cValue }
        return argv.withUnsafeMutableBufferPointer { buffer -> JSValue in
            let res = JS_Call(wrapper.context, cValue, JSCValue.undefined, argc, buffer.baseAddress)
            return JSValue(wrapper, value: res)
        }
    }

    @discardableResult
    public func call(withArguments: [Any]!) -> JSValue! {
        guard let wrapper = context, JS_IsFunction(wrapper.context, cValue) == 1 else {
            return .undefined
        }
        let arguments = (withArguments ?? []).map {
            if let arg = $0 as? JSValue {
                arg
            } else if let arg = $0 as? ConvertibleWithJavascript {
                arg.jsValue(wrapper)
            } else {
                JSValue.undefined
            }
        }
        return call(withArguments: arguments)
    }
}

// MARK: Object
extension JSValue {
    public func hasProperty(_ property: String) -> Bool {
        guard let context = context?.context else { return false }
        let atom = JS_NewAtom(context, property)
        defer { JS_FreeAtom(context, atom) }
            
        let result = JS_HasProperty(context, self.cValue, atom)
        return result == 1
    }

    public func forProperty(_ property: String) -> JSValue! {
        guard let wrapper = context else { return .undefined }
        let atom = JS_NewAtom(wrapper.context, property)
        defer { JS_FreeAtom(wrapper.context, atom) }
        
        let value = JS_GetProperty(wrapper.context, self.cValue, atom)
        
        return JSValue(wrapper, value: value)
    }
    
    public func atIndex(_ index: Int) -> JSValue! {
        guard let wrapper = context else { return .undefined }
        guard JS_IsArray(wrapper.context, self.cValue) == 1, let length = self.forProperty("length").toInt() else {
            return .undefined
        }
        guard index >= 0 && index < length else {
            return .undefined
        }

        let value = JS_GetPropertyUint32(wrapper.context, self.cValue, UInt32(index))

        return JSValue(wrapper, value: value)
    }
}

// MARK: Swift Types

public protocol ConvertibleWithJavascript {
    init?(_ context: JSContextWrapper, value: JSCValue)
    func jsValue(_ context: JSContextWrapper) -> JSValue
}

extension ConvertibleWithJavascript {
    public func jsValue(_ context: JSContextWrapper) -> JSValue {
        return .undefined
    }
}

extension String: ConvertibleWithJavascript {
    public init?(_ context: JSContextWrapper, value: JSCValue) {
        if let cString = JS_ToCString(context.context, value) {
            self.init(cString: cString)
            JS_FreeCString(context.context, cString)
        } else {
            return nil
        }
    }
    
    public func jsValue(_ context: JSContextWrapper) -> JSValue {
        let value = JS_NewString(context.context, self)
        return JSValue(context, value: value)
    }
}

extension Int32: ConvertibleWithJavascript {
    public init?(_ context: JSContextWrapper, value: JSCValue) {
        if JS_IsNumber(value) == 0 {
            return nil
        }
        
        var pres: Int32 = 0
        if JS_ToInt32(context.context, &pres, value) < 0 {
            return nil
        }
        self = pres
    }
    
    public func jsValue(_ context: JSContextWrapper) -> JSValue {
        let value = JS_NewInt32(context.context, self)
        return JSValue(context, value: value)
    }
}

extension UInt32: ConvertibleWithJavascript {
    public init?(_ context: JSContextWrapper, value: JSCValue) {
        if JS_IsNumber(value) == 0 {
            return nil
        }
        
        var pres: UInt32 = 0
        if JS_ToUint32(context.context, &pres, value) < 0 {
            return nil
        }
        self = pres
    }
    
    public func jsValue(_ context: JSContextWrapper) -> JSValue {
        let value = JS_NewUint32(context.context, self)
        return JSValue(context, value: value)
    }
}

extension Int64: ConvertibleWithJavascript {
    public init?(_ context: JSContextWrapper, value: JSCValue) {
        if JS_IsNumber(value) == 0 {
            return nil
        }
        
        var pres: Int64 = 0
        if JS_ToInt64(context.context, &pres, value) < 0 {
            return nil
        }
        self = pres
    }
    
    public func jsValue(_ context: JSContextWrapper) -> JSValue {
        let value = JS_NewInt64(context.context, self)
        return JSValue(context, value: value)
    }
}

extension Int: ConvertibleWithJavascript {
    public init?(_ context: JSContextWrapper, value: JSCValue) {
        guard let valueIn64 = Int64(context, value: value) else {
            return nil
        }
        self = .init(valueIn64)
    }
    
    public func jsValue(_ context: JSContextWrapper) -> JSValue {
        return Int64(self).jsValue(context)
    }
}

extension UInt: ConvertibleWithJavascript {
    public init?(_ context: JSContextWrapper, value: JSCValue) {
        guard let valueIn32 = UInt32(context, value: value) else {
            return nil
        }
        self = .init(valueIn32)
    }
    
    public func jsValue(_ context: JSContextWrapper) -> JSValue {
        return UInt32(self).jsValue(context)
    }
}

extension Double: ConvertibleWithJavascript {
    public init?(_ context: JSContextWrapper, value: JSCValue) {
        if JS_IsNumber(value) == 0 {
            return nil
        }
        
        var pres: Double = 0
        if JS_ToFloat64(context.context, &pres, value) < 0 {
            return nil
        }
        self = pres
    }
    
    public func jsValue(_ context: JSContextWrapper) -> JSValue {
        let value = JS_NewFloat64(context.context, self)
        return JSValue(context, value: value)
    }
}

extension Bool: ConvertibleWithJavascript {
    public init?(_ context: JSContextWrapper, value: JSCValue) {
        if JS_IsBool(value) == 0 {
            return nil
        }

        self = (JS_ToBool(context.context, value) == 1 )
    }
    
    public func jsValue(_ context: JSContextWrapper) -> JSValue {
        let value = JS_NewBool(context.context, self ? 1 : 0)
        return JSValue(context, value: value)
    }
}

extension Array: ConvertibleWithJavascript where Element: ConvertibleWithJavascript {
    public init?(_ context: JSContextWrapper, value: JSCValue) {
        guard JS_IsObject(value) != 0 else {
            return nil
        }
        
        let length = JS_GetPropertyStr(context.context, value, "length")
        defer {
            context.free(length)
        }
        var size: UInt64 = 0
        if JS_ToIndex(context.context, &size, value) < 0 {
            return nil
        }
        
        self = []
        for index in 0..<size {
            let v = JS_GetPropertyUint32(context.context, value, UInt32(index))
            if let ele = Element(context, value: v) {
                self.append(ele)
            } else {
                return nil
            }
        }
    }
    
    public func jsValue(_ context: JSContextWrapper) -> JSValue {
        fatalError("TODO")
    }
}

public enum JSError: Error, ConvertibleWithJavascript {
    case exception
    
    public init?(_ context: JSContextWrapper, value: JSCValue) {
        guard JS_IsException(value) != 0 else {
            return nil
        }
        self = .exception
    }
}
