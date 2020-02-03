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
class ChatsView: UIViewController {

	@IBOutlet var viewTitle: UIView!
	@IBOutlet var segmentedControl: UISegmentedControl!

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
	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {

		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

		tabBarItem.image = UIImage(named: "tab_chats")
		tabBarItem.title = "Chats"

		NotificationCenter.addObserver(target: self, selector: #selector(loadMembers), name: NOTIFICATION_USER_LOGGED_IN)
		NotificationCenter.addObserver(target: self, selector: #selector(actionCleanup), name: NOTIFICATION_USER_LOGGED_OUT)
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	required init?(coder aDecoder: NSCoder) {

		super.init(coder: aDecoder)
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	override func viewDidLoad() {

		super.viewDidLoad()
		navigationItem.titleView = viewTitle

		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(actionCompose))

		tableView.register(UINib(nibName: "ChatsCell", bundle: nil), forCellReuseIdentifier: "ChatsCell")

		tableView.tableFooterView = UIView()

		if (AuthUser.userId() != "") {
			loadMembers()
		}
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	override func viewDidAppear(_ animated: Bool) {

		super.viewDidAppear(animated)

		if (AuthUser.userId() != "") {
			if (Persons.fullname() != "") {

			} else { Users.onboard(target: self) }
		} else { Users.login(target: self) }
	}

	// MARK: - Realm methods
	//---------------------------------------------------------------------------------------------------------------------------------------------
	@objc func loadMembers() {

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
		let predicate2 = NSPredicate(format: "NOT objectId IN %@ AND NOT objectId IN %@", Details.deleteIds(), Details.archiveIds())

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
	func refreshTableView() {

		tableView.reloadData()

		DispatchQueue.main.async(after: 0.1) {
			self.refreshTabCounter()
		}
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func refreshTabCounter() {

		var total: Int = 0
		var lastReads: [String: Int64] = [:]

		let predicate = NSPredicate(format: "userId == %@", AuthUser.userId())
		for action in realm.objects(Action.self).filter(predicate) {
			lastReads[action.chatId] = action.lastRead
		}

		for chat in chats {
			let lastRead = lastReads[chat.objectId] ?? 0
			let format = "chatId == %@ AND userId != %@ AND createdAt > %ld AND isDeleted == NO"
			let predicate = NSPredicate(format: format, chat.objectId, AuthUser.userId(), lastRead)
			total += realm.objects(Message.self).filter(predicate).count
		}

		let item = tabBarController?.tabBar.items?[0]
		item?.badgeValue = (total != 0) ? "\(total)" : nil

		UIApplication.shared.applicationIconBadgeNumber = total
	}

	// MARK: - User actions
	//---------------------------------------------------------------------------------------------------------------------------------------------
	@objc func actionCompose() {

		let selectUserView = SelectUserView()
		selectUserView.delegate = self
		let navController = NavigationController(rootViewController: selectUserView)
		present(navController, animated: true)
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func actionNewChat() {

		if (tabBarController?.tabBar.isHidden ?? true) { return }

		tabBarController?.selectedIndex = 0

		actionCompose()
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func actionRecentUser(userId: String) {

		if (tabBarController?.tabBar.isHidden ?? true) { return }

		tabBarController?.selectedIndex = 0

		let chatId = Chats.create(userId)
		actionChatPrivate(chatId: chatId, recipientId: userId)
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func actionChatPrivate(chatId: String, recipientId: String) {

		if (segmentedControl.selectedSegmentIndex == 0) {
			let privateChatView = RCPrivateChatView(chatId: chatId, recipientId: recipientId)
			privateChatView.hidesBottomBarWhenPushed = true
			navigationController?.pushViewController(privateChatView, animated: true)
		}

		if (segmentedControl.selectedSegmentIndex == 1) {
			let privateChatView = MKPrivateChatView(chatId: chatId, recipientId: recipientId)
			privateChatView.hidesBottomBarWhenPushed = true
			navigationController?.pushViewController(privateChatView, animated: true)
		}
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func actionChatGroup(chatId: String) {

		if (segmentedControl.selectedSegmentIndex == 0) {
			let groupChatView = RCGroupChatView(chatId: chatId)
			groupChatView.hidesBottomBarWhenPushed = true
			navigationController?.pushViewController(groupChatView, animated: true)
		}

		if (segmentedControl.selectedSegmentIndex == 1) {
			let groupChatView = MKGroupChatView(chatId: chatId)
			groupChatView.hidesBottomBarWhenPushed = true
			navigationController?.pushViewController(groupChatView, animated: true)
		}
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func actionMute(at indexPath: IndexPath) {

		let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

		alert.addAction(UIAlertAction(title: "10 hours", style: .default, handler: { action in
			self.actionMute(at: indexPath, until: 10)
		}))
		alert.addAction(UIAlertAction(title: "7 days", style: .default, handler: { action in
			self.actionMute(at: indexPath, until: 168)
		}))
		alert.addAction(UIAlertAction(title: "1 month", style: .default, handler: { action in
			self.actionMute(at: indexPath, until: 720)
		}))
		alert.addAction(UIAlertAction(title: "1 year", style: .default, handler: { action in
			self.actionMute(at: indexPath, until: 8760)
		}))
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

		present(alert, animated: true)
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func actionMute(at indexPath: IndexPath, until hours: Int) {

		let seconds = TimeInterval(hours * 60 * 60)
		let dateUntil = Date().addingTimeInterval(seconds)
		let mutedUntil = dateUntil.timestamp()

		let chat = chats[indexPath.row]
		Actions.update(chatId: chat.objectId, mutedUntil: mutedUntil)
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func actionUnmute(at indexPath: IndexPath) {

		let chat = chats[indexPath.row]
		Actions.update(chatId: chat.objectId, mutedUntil: 0)
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func actionArchive(at indexPath: IndexPath) {

		let chat = chats[indexPath.row]
		Details.update(chatId: chat.objectId, isArchived: true)
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func actionDelete(at indexPath: IndexPath) {

		let chat = chats[indexPath.row]
		Details.update(chatId: chat.objectId, isDeleted: true)
	}

	// MARK: - Cleanup methods
	//---------------------------------------------------------------------------------------------------------------------------------------------
	@objc func actionCleanup() {

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

// MARK: - SelectUserDelegate
//-------------------------------------------------------------------------------------------------------------------------------------------------
extension ChatsView: SelectUserDelegate {

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func didSelectUser(person: Person) {

		let chatId = Chats.create(person.objectId)
		actionChatPrivate(chatId: chatId, recipientId: person.objectId)
	}
}

// MARK: - UIScrollViewDelegate
//-------------------------------------------------------------------------------------------------------------------------------------------------
extension ChatsView: UIScrollViewDelegate {

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {

		view.endEditing(true)
	}
}

// MARK: - UITableViewDataSource
//-------------------------------------------------------------------------------------------------------------------------------------------------
extension ChatsView: UITableViewDataSource {

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

		let cell = tableView.dequeueReusableCell(withIdentifier: "ChatsCell", for: indexPath) as! ChatsCell

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

			alert.addAction(UIAlertAction(title: "Mute", style: .default, handler: { action in
				self.actionMute(at: indexPath)
			}))
			alert.addAction(UIAlertAction(title: "Unmute", style: .default, handler: { action in
				self.actionUnmute(at: indexPath)
			}))
			alert.addAction(UIAlertAction(title: "Archive", style: .default, handler: { action in
				self.actionArchive(at: indexPath)
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
extension ChatsView: UITableViewDelegate {

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
extension ChatsView: UISearchBarDelegate {

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
