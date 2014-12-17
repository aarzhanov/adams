;;
;;  adams  -  Remote system administration tools
;;
;;  Copyright 2013,2014 Thomas de Grivel <thomas@lowh.net>
;;
;;  Permission to use, copy, modify, and distribute this software for any
;;  purpose with or without fee is hereby granted, provided that the above
;;  copyright notice and this permission notice appear in all copies.
;;
;;  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
;;  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
;;  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
;;  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
;;  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
;;  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
;;  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
;;

(in-package :adams)

(define-resource-class group () ()
  ((probe-group-in-/etc/group :properties (:name :passwd :gid :members))))

(define-resource-class user ()
  ()
  ((probe-user-in-/etc/passwd :properties (login uid gid realname home shell))
   (probe-user-groups-in-/etc/group :properties (:groups))))

(define-resource-class vnode ()
  ()
  ((probe-vnode-using-ls :properties (mode links owner group size mtime))
   (probe-vnode-using-stat :properties (:dev :ino :mode :links :uid :gid :rdev
                                        :size :atime :mtime :ctime :blksize
                                        :blocks :flags))))

(eval-when (:compile-toplevel :load-toplevel :execute)

  (defvar *cksum-legacy-algorithms*
    '(:cksum :sum :sysvsum))

  (defvar *cksum-algorithms*
    `(:md4 :md5 :rmd160 :sha1 :sha224 :sha256 :sha384 :sha512 ,@*cksum-legacy-algorithms*)))

(define-resource-class file (vnode)
  ()
  ((probe-file-content :properties (content))
   . #.(iter (for algorithm in *cksum-algorithms*)
	     (collect `(,(sym 'probe-file-cksum- algorithm)
			 :properties (,algorithm))))))

(define-resource-class directory (vnode)
  ()
  ((probe-directory-content :properties (:content))))
