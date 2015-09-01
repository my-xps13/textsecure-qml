import QtQuick 2.0
import Ubuntu.Components 1.1
import Ubuntu.Components.ListItems 1.0 as ListItem
import Ubuntu.Components.Popups 0.1
import Ubuntu.Contacts 0.1
import "../components"
import "../components/listitems"
import "../js/avatar.js" as Avatar
import "../js/time.js" as Time

TelegramPage {
    id: contactsPage

    // These values are passed on page creation.
    property bool groupChatMode: false
    property bool addToGroupMode: false
    property bool blockUserMode: false
    property int groupChatId: -1
    property string groupChatTitle: ""

    property alias isSelectingGroup: contactListView.isInSelectionMode
    property bool isGroupCountSatisfied: contactListView.selectedItems.count > 1
    property var actionsNone: []
    property list<Action> actionsSearch: [
        Action {
            iconName: "search"
            text: i18n.tr("Search")
            onTriggered: searchPressed()
        }
    ]
    property list<Action> actionsNewChat: [
        Action {
            iconName: "search"
            text: i18n.tr("Search")
            onTriggered: searchPressed()
        },
        Action {
	    iconName: "reload"
            text: i18n.tr("Refresh")
            onTriggered: refreshContacts()
        }
    ]
    property list<Action> actionsNewGroupChat: [
        Action {
            iconName: "ok"
            text: i18n.tr("Ok")
            enabled: isConnected && groupChatTitleTextField.length > 0
            onTriggered: createChatPressed()
        }
    ]

    pageTitle: {
        if (groupChatMode) {
            return i18n.tr("New group chat");
        } else if (addToGroupMode) {
            return i18n.tr("Add to group");
        } else {
            return i18n.tr("Contacts");
        }
    }
    pageSubtitle: ""

    head.actions: {
        if (isSearching) {
            return actionsNone;
        } else if (isSelectingGroup) {
            return isGroupCountSatisfied ? actionsNewGroupChat : actionsNone;
        } else {
            // also includes blockUserMode
            return actionsNewChat;
        }
    }

    body: Item {
        anchors.fill: parent

        Label {
            id: listEmptyLabel
            anchors.centerIn: parent
            fontSize: "medium"
            visible: contactListView.model.count === 0
            text: i18n.tr("No contacts")
        }

        TextField {
            // Use height and opacity, we can't animate on visibility.
            property bool isVisible: contactListView.selectedItems.count > 1

            id: groupChatTitleTextField
            anchors {
                top: parent.top
                topMargin: isVisible ? units.gu(1) : 0
                left: parent.left
                leftMargin: units.gu(1)
                right: parent.right
                rightMargin: units.gu(1)
            }
            height: isVisible ? units.gu(4) : 0
            opacity: isVisible ? 1.0 : 0.0
            placeholderText: i18n.tr("Chat title")

            Behavior on height {
                NumberAnimation { duration: 300 }
            }
            Behavior on opacity {
                NumberAnimation { duration: 300 }
            }
        }

        MultipleSelectionListView {
            id: contactListView
            property string sels : ""
            anchors {
                top: groupChatTitleTextField.visible ? groupChatTitleTextField.bottom : parent.top
                topMargin: groupChatTitleTextField.isVisible ? units.gu(1) : 0
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            clip: true

            section {
                property: "firstName"
                criteria: ViewSection.FirstCharacter
                labelPositioning: ViewSection.InlineLabels
                delegate: ListItem.Header {
                    text: section != "" ? section : "#"
                }
            }

            listModel: contactsModel.len
            listDelegate: TelegramContactsListItem {
                id: contactDelegate

                userId: uid(contactsModel.contact(index).tel)
                title: contactsModel.contact(index).name

                selected: contactListView.isSelected(contactDelegate)
                selectionMode: groupChatMode

                onItemClicked: {
			//contactListView.sels.push(contactsModel.contact(index).tel)
			contactListView.sels = contactListView.sels + ":" + contactsModel.contact(index).tel;
                    if (contactListView.isInSelectionMode) {
                        if (!contactListView.selectItem(contactDelegate)) {
                            contactListView.deselectItem(contactDelegate);
                        } else if (contactListView.selectedItems.count >= 201) {
                            // TODO Find a cleaner way.
                            contactListView.deselectItem(contactDelegate);
                        }
                        contactListView.refreshSubtitle();
                    } else {
                        openSimpleChat(contactsModel.contact(index));
                    }
                }
            }

            onSelectedItemsChanged: {
                refreshSubtitle();
            }

            onSelectionCanceled: {
                groupChatMode = false;
            }

            onSelectionDone: {
                createChat(sels.substring(1));

                groupChatMode = false;
                groupChatTitleTextField.text = "";
            }

            function refreshSubtitle() {
                var count = contactListView.selectedItems.count;
                if (groupChatMode && count > 0) {
                    var maxMembers = 200;
                    // TRANSLATORS: the first argument refers to the number of members
                    // on a group conversation. The second one refers to the maximum
                    // number of members that are supporte for groups (currently 200).
                    pageSubtitle = i18n.tr("%1 members").arg(count);
                } else {
                    pageSubtitle = "";
                }
            }
        }

        Scrollbar {
            flickableItem: contactListView
        }

        Component.onCompleted: {
            if (!textsecure.hasContacts) {
                refreshContacts();
            }
        }

    }

    onGroupChatModeChanged: {
        if (groupChatMode) {
            contactListView.startSelection();
            // onSelectedItemsChanged not working? So, call this:
        } else {
            contactListView.cancelSelection();
        }
        contactListView.refreshSubtitle();
    }

    function createChatPressed() {
        Qt.inputMethod.commit();

        var isSimpleChat = contactListView.isInSelectionMode ?
                    contactListView.selectedItems.count == 1 : true;

        var isGroupChat = !isSimpleChat && contactListView.selectedItems.count > 1;
        var hasGroupTitle = groupChatTitleTextField.text.length > 0;

        if (isSimpleChat || (isGroupChat && hasGroupTitle)) {
            contactListView.endSelection();
        }
    }

    function onBackPressed() {
        contactListView.cancelSelection();
    }

    function cancelChatPressed() {
        contactListView.cancelSelection();
    }

    function createChat(items) {
        if (items.count === 1) {
            var contact = items.get(0).model;
            openSimpleChat(contact);
        } else {
            openGroupChat(items);
        }
    }

    function openSimpleChat(contact) {
        Qt.inputMethod.hide();
        searchFinished();
	openChatById(contact.name, contact.tel);
    }

    function openGroupChat(contacts) {
	textsecure.newGroup(groupChatTitleTextField.text, contacts)
        searchFinished();
        pageStack.pop();
    }

    function onSearchTermChanged(t) {
	    console.log(t)
    }

    ContactImport {
        id: contactImporter
    }

    function refreshContacts() {
        contactImporter.contactImportDialog()
    }
}