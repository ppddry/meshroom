import QtQuick 2.9
import QtQml.Models 2.2
import QtQuick.Controls 2.3

/**
 * SortFilderDelegateModel adds sorting and filtering capabilities on a source model.
 *
 * The way model data is accessed can be overridden by redefining the modelData function.
 * This is useful if the value is not directly accessible from the model and needs
 * some extra logic.
 *
 * Regarding filtering, any type of value can be used as 'filterValue' (variant).
 * Filtering behavior can also be overridden by redefining the respectFilter function.
 *
 * Based on http://doc.qt.io/qt-5/qtquick-tutorials-dynamicview-dynamicview4-example.html
 */
DelegateModel {
    id: sortFilterModel

    property string sortRole: ""                /// the role to use for sorting
    property int sortOrder: Qt.AscendingOrder   /// the sorting order
    property string filterRole: ""              /// the role to use for filtering
    property variant filterValue                /// the value to use as filter

    onSortRoleChanged: invalidateSort()
    onSortOrderChanged: invalidateSort()
    onFilterRoleChanged: invalidateFilter()
    onFilterValueChanged: invalidateFilter()

    // display "filtered" group
    filterOnGroup: "filtered"
    // don't include elements in "items" group by default
    // as they must fall in the "unsorted" group
    items.includeByDefault: false

    groups: [
        // Group for temporarily storing items before sorting
        DelegateModelGroup {
            id: unsortedItems

            name: "unsorted"
            includeByDefault: true
            // if the source model changes, perform sorting and filtering
            onChanged: {
                // no sorting: move everything from unsorted to sorted group
                if(sortRole == "") {
                    unsortedItems.setGroups(0, unsortedItems.count, ["items"])
                }
                else {
                    sort()
                }
                // perform filter invalidation in both cases
                invalidateFilter()
            }
        },
        // Group for storing filtered items
        DelegateModelGroup {
            id: filteredItems
            name: "filtered"
        }
    ]

    /// Get data from model for 'roleName'
    function modelData(item, roleName) {
        return item.model[roleName]
    }

    /// Get the index of the first element which matches 'value' for the given 'roleName'
    function find(value, roleName) {
        for(var i = 0; i < filteredItems.count; ++i)
        {
            if(modelData(filteredItems.get(i), roleName) == value)
                return i
        }
        return -1
    }

    /**
     * Return whether 'value' respects 'filter' condition
     *
     * The test is based on the value's type:
     *   - String: check if 'value' contains 'filter' (case insensitive)
     *   - any other type: test for equality (===)
     *
     * TODO: add case sensitivity / whole word options for Strings
     */
    function respectFilter(value, filter) {
        switch(value.constructor.name)
        {
        case "String":
            return value.toLowerCase().search(filter.toLowerCase()) >= 0
        default:
            return value === filter
        }
    }

    /// Reverse sort order (toggle between Qt.AscendingOrder / Qt.DescendingOrder)
    function reverseSortOrder() {
        sortOrder = sortOrder == Qt.AscendingOrder ? Qt.DescendingOrder : Qt.AscendingOrder
    }

    property var lessThan: [
        function(left, right) { return modelData(left, sortRole) < modelData(right, sortRole) }
    ]

    function invalidateSort() {
        if(!sortFilterModel.model || !sortFilterModel.model.count)
            return;

        // move everything from "items" to "unsorted
        // will trigger "unsorted" DelegateModelGroup 'changed' signal
        items.setGroups(0, items.count, ["unsorted"])
    }

    /// Invalidate filtering
    function invalidateFilter() {
        // no filtering, add everything to the filtered group
        if(!filterRole)
        {
            items.addGroups(0, items.count, "filtered")
            return
        }

        for(var i=0; i < items.count; ++i)
        {
            // if the property value contains filterText, add it to the filtered group
            if(respectFilter(modelData(items.get(i), filterRole), filterValue))
            {
                items.addGroups(items.get(i), 1, "filtered")
            }
            else // otherwise, remove it from the filtered group
            {
                items.removeGroups(items.get(i), 1, "filtered")
            }
        }
    }

    /// Compute insert position of 'item' based on the value
    /// of its sortProperty
    function insertPosition(lessThan, item) {
        var lower = 0
        var upper = items.count
        while (lower < upper) {
            var middle = Math.floor(lower + (upper - lower) / 2)
            var result = lessThan(item, items.get(middle))
            if(sortOrder == Qt.DescendingOrder)
                result = !result
            if (result) {
                upper = middle
            } else {
                lower = middle + 1
            }
        }
        return lower
    }

    /// Perform model sorting
    function sort() {
        while (unsortedItems.count > 0) {
            var item = unsortedItems.get(0)
            var index = insertPosition(lessThan[0], item)
            item.groups = ["items"]
            items.move(item.itemsIndex, index)
        }
        // if some items were actually sorted, filter will be correctly invalidated
        // as unsortedGroup 'changed' signal will be triggered
    }

}
