//
//  GymModeDropDelegate.swift
//  LifeFlow
//
//  Drop delegate for live "gap-style" drag-and-drop reordering in GymMode.
//  Items slide out of the way during drag, not just on drop.
//

import SwiftUI

/// Drop delegate that provides live "gap-style" reordering animation.
/// Items visually slide out of the way as the user drags past them.
struct GymModeDropDelegate: DropDelegate {
    /// The exercise item this delegate is attached to
    let item: WorkoutExercise
    
    /// Binding to the exercises array for live reordering
    @Binding var exercises: [WorkoutExercise]
    
    /// The currently dragged item (nil when not dragging)
    @Binding var draggedItem: WorkoutExercise?
    
    /// Called when a drag enters this item's drop zone - triggers live animation
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem,
              draggedItem.id != item.id,
              let fromIndex = exercises.firstIndex(where: { $0.id == draggedItem.id }),
              let toIndex = exercises.firstIndex(where: { $0.id == item.id })
        else { return }
        
        // Animate the swap so items "fall away" as you drag past them
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            exercises.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }
    
    /// Called when the drop is performed - clear the dragged item
    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
    
    /// Called to determine the drop proposal
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
    
    /// Called when drag exits this item's drop zone
    func dropExited(info: DropInfo) {
        // No action needed
    }
    
    /// Validate the drop
    func validateDrop(info: DropInfo) -> Bool {
        true
    }
}
