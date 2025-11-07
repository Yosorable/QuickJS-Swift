import XCTest

@testable import QuickJS

final class QuickJSSwiftTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        
        let runtime = JSRuntime()
        XCTAssertNotNil(runtime)
        
        let context = runtime!.createContext()
        XCTAssertNotNil(context)
        
        context!.evaluateScript("console.log('Hello QuickJS');")

        let js = "let i = 10; i;"
        let result = context!.evaluateScript(js).toInt()
        XCTAssertEqual(result, 10)
        
        let property = "$SwiftTest"
        XCTAssertFalse(context!.hasGlobalProperty(name: property))
        context!.setGlobalProperty(name: property, value: "Hello world")
        XCTAssertTrue(context!.hasGlobalProperty(name: property))
        
        context!.module("swift") {
            JSModuleFunction("getMagic", argc: 0) { context, this, argc, argv in
                return 10
            }
            JSModuleFunction("getMagic2", argc: 0) { context, this, argc, argv in
                return 20
            }
            JSModuleFunction("getMagic3", argc: 2) { context, this, argc, argv in
                guard let argv = argv else { return nil }
                let res = (0..<Int(argc)).map { JSValue(context.core, value: argv[$0]).toInt() ?? 0 }.reduce(0, { $0 + $1 })
                return res
            }
        }
                
        let getMagic = """
        "use strict";
        import { getMagic, getMagic2, getMagic3 } from 'swift'

        globalThis.magic = getMagic();
        globalThis.magic2 = getMagic2();
        globalThis.magic3 = getMagic3(1, 2);
        globalThis.nums = [1, "2"];
        globalThis.obj = {"name": "Mike", "age": 20};
        globalThis.func1 = () => 1;
        globalThis.func2 = (param) => param;
        globalThis.func3 = () => {
            throw "error"
        };
        """
        
        let error = context!.evaluateScript(getMagic, type: .module).toError()
        XCTAssertNil(error)

        let magic = context!.evaluateScript("magic;").toInt()
        XCTAssertEqual(magic, 10)
        
        let magic2 = context!.evaluateScript("magic2;").toInt()
        XCTAssertEqual(magic2, 20)
        
        let magic3 = context!.evaluateScript("magic3;").toInt()
        XCTAssertEqual(magic3, 3)
        
        let nums = context!.evaluateScript("nums;")
        XCTAssertEqual(nums.forProperty("length").toInt(), 2)
        XCTAssertEqual(nums.atIndex(0).toInt(), 1)
        XCTAssertEqual(nums.atIndex(1).toString(), "2")
        
        let obj = context!.evaluateScript("obj;")
        XCTAssertEqual(obj.hasProperty("gender"), false)
        XCTAssertEqual(obj.hasProperty("name"), true)
        XCTAssertEqual(obj.forProperty("name").toInt(), nil)
        XCTAssertEqual(obj.forProperty("name").toString(), "Mike")
        XCTAssertEqual(obj.forProperty("age").toInt(), 20)
        XCTAssertEqual(obj.forProperty("age").toString(), "20")
        
        let func1 = context!.evaluateScript("func1;")
        XCTAssertEqual(func1.isFunction, true)
        XCTAssertEqual(func1.call(withArguments: []).toInt(), 1)
        
        let func2 = context!.evaluateScript("func2;")
        XCTAssertEqual(func2.isFunction, true)
        XCTAssertEqual(func2.call(withArguments: [1.jsValue(context!.core)]).toInt(), 1)
        XCTAssertEqual(func2.call(withArguments: ["1"]).toString(), "1")
        XCTAssertEqual(func2.call(withArguments: ["👋你好"]).toString(), "👋你好")
        
        let func3 = context!.evaluateScript("func3;")
        XCTAssertEqual(func3.call(withArguments: []).isException, true)
        
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
