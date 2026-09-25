import MediaPlayer

struct EntityReader {
    let entity: MPMediaEntity?

    init(_ entity: MPMediaEntity?) {
        self.entity = entity
    }

    func value<T>(_ property: String) -> T? {
        entity?.value(forProperty: property) as? T
    }

    func number(_ property: String) -> NSNumber? {
        entity?.value(forProperty: property) as? NSNumber
    }
}
