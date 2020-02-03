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
import CryptoSwift

//-------------------------------------------------------------------------------------------------------------------------------------------------
class Chats: NSObject {

	//---------------------------------------------------------------------------------------------------------------------------------------------
	class func create(_ userId: String) -> String {

		let chatId = self.chatId(userId)
		if (realm.object(ofType: Chat.self, forPrimaryKey: chatId) == nil) {

			guard let person = realm.object(ofType: Person.self, forPrimaryKey: userId) else {
				fatalError("Recipient user must exist in the local database.")
			}

			let chat = Chat()
			chat.objectId = chatId
			chat.isPrivate = true

			chat.userId1 = AuthUser.userId()
			chat.userFullname1 = Persons.fullname()
			chat.userInitials1 = Persons.initials()
			chat.userPictureAt1 = Persons.pictureAt()

			chat.userId2 = userId
			chat.userFullname2 = person.fullname
			chat.userInitials2 = person.initials()
			chat.userPictureAt2 = person.pictureAt

			let realm = try! Realm()
			try! realm.safeWrite {
				realm.add(chat, update: .modified)
			}

			let userIds = [AuthUser.userId(), userId]
			Actions.create(chatId: chatId, userIds: userIds)
			Details.create(chatId: chatId, userIds: userIds)
			Members.create(chatId: chatId, userIds: userIds)
		}

		return chatId
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	class func create(_ groupName: String, userIds: [String]) {

		let chat = Chat()
		chat.isGroup = true

		chat.groupName = groupName
		chat.groupOwnerId = AuthUser.userId()

		let realm = try! Realm()
		try! realm.safeWrite {
			realm.add(chat, update: .modified)
		}

		Actions.create(chatId: chat.objectId, userIds: userIds)
		Details.create(chatId: chat.objectId, userIds: userIds)
		Members.create(chatId: chat.objectId, userIds: userIds)
	}

	// MARK: -
	//---------------------------------------------------------------------------------------------------------------------------------------------
	class func update(chatId: String, lastMessageDate: Int64) {

		if let chat = realm.object(ofType: Chat.self, forPrimaryKey: chatId) {
			chat.update(lastMessageDate: lastMessageDate)
		}
	}

	// MARK: -
	//---------------------------------------------------------------------------------------------------------------------------------------------
	class func chatId(_ userId: String) -> String {

		let userIds = [AuthUser.userId(), userId]

		let sorted = userIds.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
		let joined = sorted.joined(separator: "")

		return joined.md5()
	}
}
