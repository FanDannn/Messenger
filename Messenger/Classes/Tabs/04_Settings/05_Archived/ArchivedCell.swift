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

//-------------------------------------------------------------------------------------------------------------------------------------------------
class ArchivedCell: UITableViewCell {

	@IBOutlet var imageUser: UIImageView!
	@IBOutlet var labelInitials: UILabel!
	@IBOutlet var labelDetails: UILabel!
	@IBOutlet var labelLastMessage: UILabel!
	@IBOutlet var labelElapsed: UILabel!
	@IBOutlet var imageMuted: UIImageView!
	@IBOutlet var viewUnread: UIView!
	@IBOutlet var labelUnread: UILabel!

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func bindData(chat: Chat) {

		if (chat.isGroup)	{ labelDetails.text = chat.groupName		}
		if (chat.isPrivate)	{ labelDetails.text = chat.userFullname()	}

		let predicate = NSPredicate(format: "chatId == %@ AND isDeleted == NO", chat.objectId)
		let message = realm.objects(Message.self).filter(predicate).sorted(byKeyPath: "createdAt").last

		labelLastMessage.text = message?.text
		labelElapsed.text = Convert.timestampToCustom(message?.createdAt)

		let predicateA = NSPredicate(format: "chatId == %@ AND userId != %@ AND typing == YES", chat.objectId, AuthUser.userId())
		if (realm.objects(Action.self).filter(predicateA).count != 0) {
			labelLastMessage.text = "Typing..."
		}

		let predicateB = NSPredicate(format: "chatId == %@ AND userId == %@", chat.objectId, AuthUser.userId())
		if let action = realm.objects(Action.self).filter(predicateB).first {
			imageMuted.isHidden = action.mutedUntil < Date().timestamp()

			let format = "chatId == %@ AND userId != %@ AND createdAt > %ld AND isDeleted == NO"
			let predicate = NSPredicate(format: format, chat.objectId, AuthUser.userId(), action.lastRead)
			let count = realm.objects(Message.self).filter(predicate).count

			labelUnread.text = "\(count)"
			viewUnread.isHidden = (count == 0)
		}
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func loadImage(chat: Chat, tableView: UITableView, indexPath: IndexPath) {

		if (chat.isPrivate) {
			if let path = MediaDownload.pathUser(chat.userId()) {
				imageUser.image = UIImage.image(path, size: 50)
				labelInitials.text = nil
			} else {
				imageUser.image = UIImage(named: "archived_blank")
				labelInitials.text = chat.userInitials()
				downloadImage(chat: chat, tableView: tableView, indexPath: indexPath)
			}
		}

		if (chat.isGroup) {
			imageUser.image = UIImage(named: "archived_blank")
			labelInitials.text = String(chat.groupName.prefix(1))
		}
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func downloadImage(chat: Chat, tableView: UITableView, indexPath: IndexPath) {

		MediaDownload.startUser(chat.userId(), pictureAt: chat.userPictureAt()) { image, error in
			let indexSelf = tableView.indexPath(for: self)
			if ((indexSelf == nil) || (indexSelf == indexPath)) {
				if (error == nil) {
					self.imageUser.image = image?.square(to: 50)
					self.labelInitials.text = nil
				} else if (error!.code() == 102) {
					DispatchQueue.main.async(after: 0.5) {
						self.downloadImage(chat: chat, tableView: tableView, indexPath: indexPath)
					}
				}
			}
		}
	}
}
