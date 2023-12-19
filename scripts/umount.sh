# umount before badckup
umount() {
    mount_path="/home/ming/Documents/KeePass"
    sudo umount "$mount_path"
}