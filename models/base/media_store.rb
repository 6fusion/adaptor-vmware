# @api public
# This class file should not be modified if you don't understand what you are doing.
class Base::MediaStore < Main
  attr_accessor :local_path,
    :remote_path

  def self.mount(_local_mount_path, _remote_mount_path)
    logger.info("creating local mount path: #{_local_mount_path}")
    Kernel.system("sudo mkdir -p #{_local_mount_path}")
    logger.info("created local mount path: #{_local_mount_path}")

    logger.info("mounting #{_remote_mount_path} -> #{_local_mount_path}")
    mount_cmd = "sudo mount -t nfs #{_remote_mount_path} #{_local_mount_path}" # -o sync 2>&1

    logger.info("#{mount_cmd}")
    Kernel.system("#{mount_cmd}")
    logger.info("mounted: #{_local_mount_path}")

    return self.new({ local_path: _local_mount_path, remote_path: _remote_mount_path })
  end

  def self.unmount(_local_mount_path)
    logger.info("unmounting #{_local_mount_path}")
    Kernel.system("sudo umount #{_local_mount_path}")
    logger.info("unmounted #{_local_mount_path}")

    logger.info("deleting local mount directory: #{_local_mount_path}")
    Kernel.system("sudo rmdir #{_local_mount_path}")
    logger.info("deleted local mount directory: #{_local_mount_path}")

    return self.new({ local_path: _local_mount_path, remote_path: '' })
  end
end
