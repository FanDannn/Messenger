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
class Chat: SyncObject {

	@objc dynamic var isGroup = false
	@objc dynamic var isPrivate = false

	@objc dynamic var groupName = ""
	@objc dynamic var groupOwnerId = ""
	@objc dynamic var groupDeleted = false

	@objc dynamic var userId1 = ""
	@objc dynamic var userFullname1 = ""
	@objc dynamic var userInitials1 = ""
	@objc dynamic var userPictureAt1: Int64 = 0

	@objc dynamic var userId2 = ""
	@objc dynamic var userFullname2 = ""
	@objc dynamic var userInitials2 = ""
	@objc dynamic var userPictureAt2: Int64 = 0

	@objc dynamic var lastMessageDate: Int64 = 0

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func userId() -> String {

		return (userId1 != AuthUser.userId()) ? userId1 : userId2
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func userFullname() -> String {

		return (userId1 != AuthUser.userId()) ? userFullname1 : userFullname2
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func userInitials() -> String {

		return (userId1 != AuthUser.userId()) ? userInitials1 : userInitials2
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func userPictureAt() -> Int64 {

		return (userId1 != AuthUser.userId()) ? userPictureAt1 : userPictureAt2
	}

	// MARK: -
	//---------------------------------------------------------------------------------------------------------------------------------------------
	func update(groupName value: String) {

		if (groupName == value) { return }

		let realm = try! Realm()
		try! realm.safeWrite {
			groupName = value
			syncRequired = true
		}
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func update(groupDeleted value: Bool) {

		if (groupDeleted == value) { return }

		let realm = try! Realm()
		try! realm.safeWrite {
			groupDeleted = value
			syncRequired = true
		}
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func update(lastMessageDate value: Int64) {

		if (lastMessageDate == value) { return }

		let realm = try! Realm()
		try! realm.safeWrite {
			lastMessageDate = value
			syncRequired = true
		}
	}
}
