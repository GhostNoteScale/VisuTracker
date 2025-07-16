//
//  VisuItem+CoreDataProperties.swift
//  VisuTracker
//
//  Created by Go Nakazawa on 2025/06/28.
//
//

import Foundation
import CoreData


extension VisuItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<VisuItem> {
        return NSFetchRequest<VisuItem>(entityName: "VisuItem")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var imageURL: String?
    @NSManaged public var pageURL: String?
    @NSManaged public var price: String?
    @NSManaged public var productName: String?
    @NSManaged public var timestamp: Date?

}

extension VisuItem : Identifiable {

}
