
import SwiftUI

struct ItemPicker: View {
    @ObservedObject var repo: Repository = Repository.shared
    @State var search: String = ""
    @State var foundItems: [Item] = []
    
    @State var newItem: Item = Item(id: "", name: "", type: .produce)
    @State var newItemSelected: Bool = false
    
    var onSelect: (Item) -> ()
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            TextField("Search", text: $search)
            if search == "" {
                ForEach(repo.allItems) { item in
                    Button(item.name) {
                        onSelect(item)
                        dismiss()
                    }
                }
            } else {
                
                if foundItems.isEmpty {
                    Section {
                        DisclosureGroup {
                            HStack {
                                TextField("Item Name", text: $newItem.name)
                                Picker(selection: $newItem.type) {
                                    Label("Produce", systemImage: "carrot").tag(ItemType.produce)
                                    Label("Meals", systemImage: "takeoutbag.and.cup.and.straw").tag(ItemType.cooked)
                                } label: {
                                    EmptyView()
                                }
                            }
                            Button("Done") {
                                onSelect(newItem)
                                dismiss()
                            }
                        } label: {
                            Label("Add New", systemImage: "plus")
                        }
                    } header: {
                        Text("Can't find your item?")
                    }
                } else {
                    Section {
                        ForEach(foundItems) { item in
                            Button(item.name) {
                                onSelect(item)
                                dismiss()
                            }
                        }
                    } header: {
                        Text("Results")
                    }
                }
            }
        }
        .onChange(of: search) { v in
            if v.isEmpty {
                foundItems = []
                return
            }
            foundItems = repo
                .allItems
                .filter{$0.name.localizedCaseInsensitiveContains(v)}
        }
        .task {
            do {
                try await repo.getAllItems()
            } catch {
                print(error)
            }
        }
        .onChange(of: newItem.name) { n in
            newItemSelected = true
            newItem.id = identifier(for: n)
        }
        .onChange(of: newItem.type) { _ in
            newItemSelected = true
        }
    }
}

//#Preview {
//    ItemPicker()
//}
