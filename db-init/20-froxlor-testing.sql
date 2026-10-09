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

-- The test suite runs against its own database: the queue workers and the scheduler of the dev
-- stack work on `froxlor` and would hold locks the tests wait for (php artisan test, phpunit.xml).
-- Runs only when the database volume is created.
CREATE DATABASE IF NOT EXISTS `froxlor_testing` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON `froxlor_testing`.* TO 'froxlor'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
