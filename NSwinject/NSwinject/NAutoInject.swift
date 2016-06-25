//
//  NAutoInject.swift
//  NSwinject
//
//  Created by Nghia Nguyen on 6/25/16.
//  This class implemented in Dip project. I just bring it to Swiniject because of "try" convention.
//  See more: https://github.com/AliSoftware/Dip

import Swinject

infix operator <- {}
public func <-<T>(left: T, right: [Container]) -> T {
    
    nk_inject(left, containers: right)
    
    return left
}

public func nk_inject<T>(any: T, containers: [Container]) {
    let mirror = Mirror(reflecting: any)
    
    for child in mirror.children {
        guard let injectedValue = child.value as? AutoInjectedPropertyBox else {
            nk_inject(child.value, containers: containers)
            continue
        }
        
        for container in containers {
            if injectedValue.resolve(container) {
                if let value = injectedValue.anyValue() {
                    nk_inject(value, containers: containers)
                }
                
                break
            }
        }
    }
}

public protocol AutoInjectedPropertyBox: class {
    ///The type of wrapped property.
    static var wrappedType: Any.Type { get }
    
    /**
     This method will be called by `DependencyContainer` during processing resolved instance properties.
     In this method you should resolve an instance for wrapped property and store a reference to it.
     
     - parameter container: A container to be used to resolve an instance
     
     - note: This method is not intended to be called manually, `DependencyContainer` will call it by itself.
     */
    func resolve(container: Container) -> Bool
    
    func anyValue() -> Any?
}

/**
 Use this wrapper to identify _strong_ properties of the instance that should be
 auto-injected by `DependencyContainer`. Type T can be any type.
 
 - warning: Do not define this property as optional or container will not be able to inject it.
 Instead define it with initial value of `Injected<T>()`.
 
 **Example**:
 
 ```swift
 class ClientImp: Client {
 var service = Injected<Service>()
 }
 ```
 - seealso: `InjectedWeak`
 
 */
public final class Injected<T>: _InjectedPropertyBox<T>, AutoInjectedPropertyBox {
    
    ///The type of wrapped property.
    public static var wrappedType: Any.Type {
        return T.self
    }
    
    ///Wrapped value.
    public private(set) var value: T? {
        didSet {
            if let value = value { didInject(value) }
        }
    }
    
    /**
     Creates a new wrapper for auto-injected property.
     
     - parameters:
     - required: Defines if the property is required or not.
     If container fails to inject required property it will als fail to resolve
     the instance that defines that property. Default is `true`.
     - tag: An optional tag to use to lookup definitions when injecting this property. Default is `nil`.
     - didInject: block that will be called when concrete instance is injected in this property.
     Similar to `didSet` property observer. Default value does nothing.
     */
    public convenience init(required: Bool = true, didInject: T -> () = { _ in }) {
        self.init(value: nil, required: required, name: nil, overrideTag: false, didInject: didInject)
    }
    
    public convenience init(required: Bool = true, name: String?, didInject: T -> () = { _ in }) {
        self.init(value: nil, required: required, name: name, overrideTag: true, didInject: didInject)
    }
    
    private init(value: T?, required: Bool = true, name: String?, overrideTag: Bool, didInject: T -> ()) {
        self.value = value
        super.init(required: required, name: name, overrideTag: overrideTag, didInject: didInject)
    }
    
    public func resolve(container: Container) -> Bool {
        let resolved: T? = super.resolve(container)
        value = resolved
        
        return value != nil
    }
    
    public func anyValue() -> Any? {
        return self.value as Any
    }
    
    /// Returns a new wrapper with provided value.
    public func setValue(value: T?) -> Injected {
        guard (required && value != nil) || !required else {
            fatalError("Can not set required property to nil.")
        }
        
        return Injected(value: value, required: required, name: name, overrideTag: overrideTag, didInject: didInject)
    }
    
}

/**
 Use this wrapper to identify _weak_ properties of the instance that should be
 auto-injected by `DependencyContainer`. Type T should be a **class** type.
 Otherwise it will cause runtime exception when container will try to resolve the property.
 Use this wrapper to define one of two circular dependencies to avoid retain cycle.
 
 - note: The only difference between `InjectedWeak` and `Injected` is that `InjectedWeak` uses
 _weak_ reference to store underlying value, when `Injected` uses _strong_ reference.
 For that reason if you resolve instance that has a _weak_ auto-injected property this property
 will be released when `resolve` will complete.
 
 Use `InjectedWeak<T>` to define one of two circular dependecies if another dependency is defined as `Injected<U>`.
 This will prevent a retain cycle between resolved instances.
 
 - warning: Do not define this property as optional or container will not be able to inject it.
 Instead define it with initial value of `InjectedWeak<T>()`.
 
 **Example**:
 
 ```swift
 class ServiceImp: Service {
 var client = InjectedWeak<Client>()
 }
 
 ```
 
 - seealso: `Injected`
 
 */
public final class InjectedWeak<T>: _InjectedPropertyBox<T>, AutoInjectedPropertyBox {
    
    //Only classes (means AnyObject) can be used as `weak` properties
    //but we can not make <T: AnyObject> because that will prevent using protocol as generic type
    //so we just rely on user reading documentation and passing AnyObject in runtime
    //also we will throw fatal error if type can not be casted to AnyObject during resolution.
    
    ///The type of wrapped property.
    public static var wrappedType: Any.Type {
        return T.self
    }
    
    private weak var _value: AnyObject? = nil {
        didSet {
            if let value = value { didInject(value) }
        }
    }
    
    ///Wrapped value.
    public var value: T? {
        return _value as? T
    }
    
    /**
     Creates a new wrapper for weak auto-injected property.
     
     - parameters:
     - required: Defines if the property is required or not.
     If container fails to inject required property it will als fail to resolve
     the instance that defines that property. Default is `true`.
     - tag: An optional tag to use to lookup definitions when injecting this property. Default is `nil`.
     - didInject: block that will be called when concrete instance is injected in this property.
     Similar to `didSet` property observer. Default value does nothing.
     */
    public convenience init(required: Bool = true, didInject: T -> () = { _ in }) {
        self.init(value: nil, required: required, name: nil, overrideTag: false, didInject: didInject)
    }
    
    public convenience init(required: Bool = true, name: String?, didInject: T -> () = { _ in }) {
        self.init(value: nil, required: required, name: name, overrideTag: true, didInject: didInject)
    }
    
    private init(value: T?, required: Bool = true, name: String?, overrideTag: Bool, didInject: T -> ()) {
        self._value = value as? AnyObject
        super.init(required: required, name: name, overrideTag: overrideTag, didInject: didInject)
    }
    
    public func resolve(container: Container) -> Bool {
        let resolved: T? = super.resolve(container)
        if required && !(resolved is AnyObject) {
            fatalError("\(T.self) can not be casted to AnyObject. InjectedWeak wrapper should be used to wrap only classes.")
        }
        _value = resolved as? AnyObject
        
        return _value != nil
    }
    
    public func anyValue() -> Any? {
        return self._value as Any
    }
    
    /// Returns a new wrapper with provided value.
    public func setValue(value: T?) -> InjectedWeak {
        let _value = value as? AnyObject
        if value != nil && _value == nil {
            fatalError("\(T.self) can not be casted to AnyObject. InjectedWeak wrapper should be used to wrap only classes.")
        }
        guard (required && _value != nil) || !required else {
            fatalError("Can not set required property to nil.")
        }
        
        return InjectedWeak(value: value, required: required, name: name, overrideTag: overrideTag, didInject: didInject)
    }
    
}

private class _InjectedPropertyBox<T> {
    
    let required: Bool
    let didInject: T -> ()
    let name: String?
    let overrideTag: Bool
    
    init(required: Bool = true, name: String?, overrideTag: Bool, didInject: T -> () = { _ in }) {
        self.required = required
        self.name = name
        self.overrideTag = overrideTag
        self.didInject = didInject
    }
    
    private func resolve(container: Container) -> T? {
        let resolved: T?
        let tag = overrideTag ? self.name : nil
        resolved = container.resolve(T.self, name: tag)
        
        if let resolved = resolved {
            didInject(resolved)
        }
        
        return resolved
    }
    
}

