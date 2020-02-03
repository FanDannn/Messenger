//
// Copyright (c) 2020 Related Code - http://relatedcode.com
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import RealmSwift

//-------------------------------------------------------------------------------------------------------------------------------------------------
class ArchivedView: UIViewController {

	@IBOutlet var searchBar: UISearchBar!
	@IBOutlet var tableView: UITableView!

	private var tokenMembers: NotificationToken? = nil
	private var tokenDetails: NotificationToken? = nil
	private var tokenChats: NotificationToken? = nil
	private var tokenActions: NotificationToken? = nil
	private var tokenMessages: NotificationToken? = nil

	private var members	= realm.objects(Member.self).filter(falsepredicate)
	private var details	= realm.objects(Detail.self).filter(falsepredicate)
	private var chats	= realm.objects(Chat.self).filter(falsepredicate)
	private var actions	= realm.objects(Action.self).filter(falsepredicate)
	private var messages = realm.objects(Message.self).filter(falsepredicate)

	//---------------------------------------------------------------------------------------------------------------------------------------------
	override func viewDidLoad() {

		super.viewDidLoad()
		title = "Archived Chats"

		tableView.register(UINib(nibName: "ArchivedCell", bundle: nil), forCellReuseIdentifier: "ArchivedCell")

		tableView.tableFooterView = UIView()

		loadMembers()
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	override func viewWillDisappear(_ animated: Bool) {

		super.viewWillDisappear(animated)

		if (isMovingFromParent) {
			actionCleanup()
		}
	}

	// MARK: - Realm methods
	//---------------------------------------------------------------------------------------------------------------------------------------------
	func loadMembers() {

		let predicate = NSPredicate(format: "userId == %@ AND isActive == YES", AuthUser.userId())
		members = realm.objects(Member.self).filter(predicate)

		tokenMembers?.invalidate()
		members.safeObserve({ changes in
			self.loadDetails()
			DispatchQueue.main.async(after: 0.1) {
				self.loadActions()
				self.loadMessages()
			}
		}, completion: { token in
			self.tokenMembers = token
		})
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func loadDetails() {

		let predicate = NSPredicate(format: "userId == %@", AuthUser.userId())
		details = realm.objects(Detail.self).filter(predicate)

		tokenDetails?.invalidate()
		details.safeObserve({ changes in
			self.loadChats()
		}, completion: { token in
			self.tokenDetails = token
		})
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func loadChats(text: String = "") {

		let predicate1 = NSPredicate(format: "objectId IN %@ AND groupDeleted == NO AND lastMessageDate != 0", Members.chatIds())
		let predicate2 = NSPredicate(format: "NOT objectId IN %@ AND objectId IN %@", Details.deleteIds(), Details.archiveIds())

		let format = "groupName CONTAINS[c] %@ OR userFullname1 CONTAINS[c] %@ OR userFullname2 CONTAINS[c] %@"
		let predicate3 = (text != "") ? NSPredicate(format: format, text, text, text) : NSPredicate(value: true)

		let predicate = NSCompoundPredicate(type: .and, subpredicates: [predicate1, predicate2, predicate3])
		chats = realm.objects(Chat.self).filter(predicate).sorted(byKeyPath: "lastMessageDate", ascending: false)

		tokenChats?.invalidate()
		chats.safeObserve({ changes in
			self.refreshTableView()
		}, completion: { token in
			self.tokenChats = token
		})
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func loadActions() {

		let predicate = NSPredicate(format: "chatId IN %@", Members.chatIds())
		actions = realm.objects(Action.self).filter(predicate)

		tokenActions?.invalidate()
		actions.safeObserve({ changes in
			self.refreshTableView()
		}, completion: { token in
			self.tokenActions = token
		})
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func loadMessages() {

		let predicate = NSPredicate(format: "chatId IN %@ AND isDeleted == NO", Members.chatIds())
		messages = realm.objects(Message.self).filter(predicate)

		tokenMessages?.invalidate()
		messages.safeObserve({ changes in
			self.refreshTableView()
		}, completion: { token in
			self.tokenMessages = token
		})
	}

	// MARK: - Refresh methods
	//---------------------------------------------------------------------------------------------------------------------------------------------
	@objc func refreshTableView() {

		tableView.reloadData()
	}

	// MARK: - User actions
	//---------------------------------------------------------------------------------------------------------------------------------------------
	func actionChatPrivate(chatId: String, recipientId: String) {

		let privateChatView = RCPrivateChatView(chatId: chatId, recipientId: recipientId)
		navigationController?.pushViewController(privateChatView, animated: true)
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func actionChatGroup(chatId: String) {

		let groupChatView = RCGroupChatView(chatId: chatId)
		navigationController?.pushViewController(groupChatView, animated: true)
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func actionUnarchive(at indexPath: IndexPath) {

		let chat = chats[indexPath.row]
		Details.update(chatId: chat.objectId, isArchived: false)
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func actionDelete(at indexPath: IndexPath) {

		let chat = chats[indexPath.row]
		Details.update(chatId: chat.objectId, isDeleted: true)
	}

	// MARK: - Cleanup methods
	//---------------------------------------------------------------------------------------------------------------------------------------------
	func actionCleanup() {

		tokenMembers?.invalidate()
		tokenDetails?.invalidate()
		tokenChats?.invalidate()
		tokenActions?.invalidate()
		tokenMessages?.invalidate()

		members	= realm.objects(Member.self).filter(falsepredicate)
		details	= realm.objects(Detail.self).filter(falsepredicate)
		chats	= realm.objects(Chat.self).filter(falsepredicate)
		actions	= realm.objects(Action.self).filter(falsepredicate)
		messages = realm.objects(Message.self).filter(falsepredicate)

		refreshTableView()
	}
}

// MARK: - UIScrollViewDelegate
//-------------------------------------------------------------------------------------------------------------------------------------------------
extension ArchivedView: UIScrollViewDelegate {

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {

		view.endEditing(true)
	}
}

// MARK: - UITableViewDataSource
//-------------------------------------------------------------------------------------------------------------------------------------------------
extension ArchivedView: UITableViewDataSource {

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func numberOfSections(in tableView: UITableView) -> Int {

		return 1
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

		return chats.count
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

		let cell = tableView.dequeueReusableCell(withIdentifier: "ArchivedCell", for: indexPath) as! ArchivedCell

		let chat = chats[indexPath.row]
		cell.bindData(chat: chat)
		cell.loadImage(chat: chat, tableView: tableView, indexPath: indexPath)

		return cell
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {

		return true
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {

		let buttonDelete = UITableViewRowAction(style: .default, title: "Delete") { action, indexPath in
			let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

			alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { action in
				self.actionDelete(at: indexPath)
			}))
			alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

			self.present(alert, animated: true)
		}

		let buttonMore = UITableViewRowAction(style: .default, title: "More") { action, indexPath in
			let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

			alert.addAction(UIAlertAction(title: "Unarchive", style: .default, handler: { action in
				self.actionUnarchive(at: indexPath)
			}))
			alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

			self.present(alert, animated: true)
		}

		buttonDelete.backgroundColor = .systemRed
		buttonMore.backgroundColor = .systemGray

		return [buttonDelete, buttonMore]
	}
}

// MARK: - UITableViewDelegate
//-------------------------------------------------------------------------------------------------------------------------------------------------
extension ArchivedView: UITableViewDelegate {

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

		tableView.deselectRow(at: indexPath, animated: true)

		let chat = chats[indexPath.row]

		if (chat.isGroup) {
			actionChatGroup(chatId: chat.objectId)
		}
		if (chat.isPrivate) {
			actionChatPrivate(chatId: chat.objectId, recipientId: chat.userId())
		}
	}
}

// MARK: - UISearchBarDelegate
//-------------------------------------------------------------------------------------------------------------------------------------------------
extension ArchivedView: UISearchBarDelegate {

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {

		loadChats(text: searchText)
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func searchBarTextDidBeginEditing(_ searchBar_: UISearchBar) {

		searchBar.setShowsCancelButton(true, animated: true)
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func searchBarTextDidEndEditing(_ searchBar_: UISearchBar) {

		searchBar.setShowsCancelButton(false, animated: true)
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func searchBarCancelButtonClicked(_ searchBar_: UISearchBar) {

		searchBar.text = ""
		searchBar.resignFirstResponder()
		loadChats()
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func searchBarSearchButtonClicked(_ searchBar_: UISearchBar) {

		searchBar.resignFirstResponder()
	}
}
