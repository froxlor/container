-- SPDX-FileCopyrightText: 2026 the froxlor Team (see AUTHORS)
-- SPDX-License-Identifier: LGPL-3.0-or-later WITH LicenseRef-froxlor-Extension-Package-Exception
--
-- This file is part of the froxlor project.
--
-- This library is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as
-- published by the Free Software Foundation, either version 3 of the
-- License, or (at your option) any later version, with the froxlor
-- Extension Package Exception (see LICENSE-EXCEPTION).
--
-- This library is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
-- Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public
-- License along with this library. If not, see
-- <https://www.gnu.org/licenses/>.

-- froxlor creates a read-only database user per mail node (Postfix/Dovecot lookups) and grants it
-- SELECT on the views of that node: the panel user needs CREATE USER and GRANT OPTION.
-- Runs only when the database volume is created.
GRANT CREATE USER ON *.* TO 'froxlor'@'%';
GRANT ALL PRIVILEGES ON `froxlor`.* TO 'froxlor'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
