/// Copyright (c) 2017-18 Nicolas Christe
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in all
/// copies or substantial portions of the Software.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
/// SOFTWARE.

import Foundation

/// A Service that can be registred in a `Container`
public protocol Service: class {
    /// Type of the servuce
    associatedtype ServiceType = Self
    /// service descriptor
    static var descriptor: Container.ServiceDescriptor<ServiceType> { get }
}

/// A simple dependency Container.
public class Container {
    /// Errors
    public enum ContainerError: Error {
        /// Service not found
        case notFound
        /// Service dependencies loop
        case dependencyLoop
        /// Service already registred
        case alreadyRegistred
        /// Exception instantiating service
        case instantiationError(Error)
        /// Serivce doesn't implement API given in descriptor
        case wrongServiceDefinition
    }

    /// Service descriptor
    /// - paramter Service: service type
    public class ServiceDescriptor<Service> {
        /// Service id
        fileprivate var sid: ObjectIdentifier!
        /// Constructor
        public init() {
            sid = ObjectIdentifier(self)
        }
    }

    /// A reference on a service or a service factory
    private enum ServiceRef {
        /// Ref on a service instance
        case instance(AnyObject)
        /// Ref on a service factory
        case factory((Container) throws -> AnyObject)
        /// Transitive state: service is currently instantiated. Used for dependency loop detection
        case instantiating
    }

    private var services = [ObjectIdentifier: ServiceRef]()
    private let queue: DispatchQueue
    private let dispatchSpecificKey = DispatchSpecificKey<Bool>()

    /// Constructor
    public init(queue: DispatchQueue = DispatchQueue(label: "Container")) {
        self.queue = queue
        queue.setSpecific(key: dispatchSpecificKey, value: true)
    }

    deinit {
        queue.setSpecific(key: dispatchSpecificKey, value: nil)
    }

    /// Register a service
    ///
    /// - Parameters:
    ///   - factory: factory to create the service
    ///   - container: self
    ///   - service: service to register
    /// - Throws:  ContainerError.alreadyRegistred if serivce already registered
    public func register<S: Service>(factory: @escaping (_ container: Container) throws -> S) throws {
        guard services[S.descriptor.sid] == nil else {
            throw ContainerError.alreadyRegistred
        }
        services[S.descriptor.sid] = .factory(factory)
    }

    /// Get a service. Service is instentiated if required.
    ///
    /// - Parameter descriptor: descriptor of the service to get
    /// - Returns: Service instance if found
    /// - Throws:  ContainerError if there is a error getting or creating the service
    public func getService<S>(descriptor: ServiceDescriptor<S>) throws -> S {
        if DispatchQueue.getSpecific(key: dispatchSpecificKey) == nil {
            return try queue.sync {
                return try self.getServiceQueue(descriptor: descriptor)
            }
        } else {
            return try getServiceQueue(descriptor: descriptor)
        }
    }

    /// Get a service. Service is instentiated if required.
    ///
    /// - Parameter descriptor: descriptor of the service to get
    /// - Returns: Service instance if found
    /// - Throws:  ContainerError if there is a error getting or creating the service
    private func getServiceQueue<S>(descriptor: ServiceDescriptor<S>) throws -> S {
        if let serviceRef = services[descriptor.sid] {
            switch serviceRef {
            case .instance(let service):
                // swiftlint:disable:next force_cast
                return service as! S
            case .factory(let factory):
                return try create(descriptor: descriptor, factory: factory)
            case .instantiating:
                throw ContainerError.dependencyLoop
            }
        }
        throw ContainerError.notFound
    }

    /// Instantiate a service
    ///
    /// - Parameters:
    ///   - descriptor: descriptor of the service to create
    ///   - factory: service factory closure
    ///   - container: self
    /// - Returns: created service service
    /// - Throws:  ContainerError if there is a error creating the service
    private func create<S>(descriptor: ServiceDescriptor<S>, factory: (_ container: Container) throws ->  AnyObject)
        throws -> S {
            services[descriptor.sid] = .instantiating
            do {
                let instance = try factory(self)
                if let service = instance as? S {
                    services[descriptor.sid] = .instance(instance)
                    return service
                }
            } catch let containerError as ContainerError {
                throw containerError
            } catch let err {
                throw ContainerError.instantiationError(err)
            }
            throw ContainerError.wrongServiceDefinition
    }
}