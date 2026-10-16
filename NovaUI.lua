--[[
	NovaUI - Roblox UI Library (Luau)  ·  ธีมโทนเทาเรียบ + สีไล่เฉดที่ไอคอน/ปุ่ม
	ใช้เป็น ModuleScript ชื่อ "NovaUI" แล้ว require จาก LocalScript

	เอกลักษณ์:
	  • พื้นหลังและขอบเป็นเทากลางๆ ไม่มีสี ส่วนสีไล่เฉด (Accent → Accent2) ใช้เฉพาะไอคอน/ปุ่ม/สวิตช์/slider
	  • แถบไอคอนแคบทางซ้าย (โลโก้บน / รูปผู้ใช้ล่าง / หมวดเลื่อนได้ตรงกลาง) ชื่อแท็บขึ้นเมื่อชี้
	  • เปิด/ปิดแบบ Dynamic Island: หน้าต่างพับเป็นแคปซูลกลางบนจอ กดแคปซูลหรือ RightShift เพื่อขยายกลับ
	  • สวิตช์แบบ OFF | ON, dropdown แสดงตัวเลือกเป็นชิป, ตัวเลขใช้ฟอนต์ Code
	  • มีธีมสำเร็จรูป 4 แบบ: "Neon" (ค่าเริ่มต้น), "Crimson", "Cyber", "Toxic"

	API:
		NovaUI:SetTheme("Crimson")  หรือ  NovaUI:SetTheme({ Accent = ..., Accent2 = ... })   -- เรียกก่อน CreateWindow
		local Window  = NovaUI:CreateWindow({ Title, Version, Subtitle, Logo, Size, ToggleKey, Parent })
		local Tab     = Window:AddTab({ Name, Group, Icon, Color })
		local Section = Tab:AddSection({ Title, Description, Icon, Color })   -- ใส่ Icon เพื่อโชว์ไอคอนหน้าหัวข้อ / ไม่ใส่ Title = แผงเปล่า

		Section:AddToggle({ Title, Description, Default, Callback })
		Section:AddButton({ Title, Description, ButtonText, Callback })
		Section:AddSlider({ Title, Description, Min, Max, Step, Default, Suffix, Callback })
		Section:AddDropdown({ Title, Description, Options, Max, Multi, Popup, Default, Placeholder, Callback })
			Max = 1   → เลือกได้อันเดียว (ค่าเริ่มต้นถ้าไม่ใส่ Multi)
			Max = N   → ติ๊กได้สูงสุด N อัน เช่น 2, 3, 5
			Multi = true หรือ Max = 0 → ติ๊กได้ไม่จำกัด
			Popup     → true/false บังคับใช้หน้าต่างเลือกแยก (ไม่ใส่ = เปิดอัตโนมัติเมื่อมีตัวเลือกเกิน 6 อัน)
		Section:AddLabel(text)

	Dropdown Options ใส่เป็น string หรือ table ก็ได้:
		{ Name = "ชื่อ", Icon = "👤" หรือ "rbxassetid://123", Right = "3:45", Highlight = false }
	แจ้งเตือน: Window:Notify({ Title, Content, Type = "info"|"success"|"warning"|"error", Duration = 4, Icon, Callback })
	Dropdown methods: :Get() :Set(v) :SetOptions(list) :SetRight(name, text, highlight) :SelectAll() :Clear()
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local C = Color3.fromRGB

-- พื้นหลัง/ขอบ/ข้อความ เป็นโทนเทากลางๆ ไม่มีสี (ทุกธีมใช้ร่วมกัน)
local Surfaces = {
	Background = C(12, 12, 15), Rail = C(18, 18, 22), Panel = C(19, 19, 23), Raised = C(30, 30, 36),
	Field = C(9, 9, 11), Line = C(38, 38, 45), Text = C(240, 240, 243), Muted = C(136, 136, 148),
	Off = C(24, 24, 29),
}

-- ธีมสำเร็จรูป: เปลี่ยนเฉพาะสีของปุ่ม/สวิตช์/slider/ไอคอน
local Presets = {
	Neon    = { Accent = C(168, 85, 247), Accent2 = C(34, 211, 238),  AccentText = C(255, 255, 255), Ready = C(52, 255, 170), Danger = C(255, 77, 109) },
	Crimson = { Accent = C(255, 45, 85),  Accent2 = C(255, 122, 60),  AccentText = C(255, 255, 255), Ready = C(255, 196, 60), Danger = C(255, 77, 109) },
	Cyber   = { Accent = C(0, 200, 255),  Accent2 = C(80, 120, 255),  AccentText = C(2, 12, 24),     Ready = C(60, 255, 170), Danger = C(255, 77, 109) },
	Toxic   = { Accent = C(57, 255, 120), Accent2 = C(200, 255, 60),  AccentText = C(4, 18, 8),      Ready = C(0, 220, 255),  Danger = C(255, 77, 109) },
}

local Theme = {
	Font       = Enum.Font.GothamMedium,
	FontBold   = Enum.Font.GothamBold,
	FontNumber = Enum.Font.Code,
	Warning    = C(255, 176, 32),
}
for k, v in pairs(Surfaces) do Theme[k] = v end
for k, v in pairs(Presets.Neon) do Theme[k] = v end

local Library = { Theme = Theme }
local WindowClass, TabClass, SectionClass = {}, {}, {}
WindowClass.__index = WindowClass
TabClass.__index = TabClass
SectionClass.__index = SectionClass

local RAIL_W = 64
local HEADER_H = 60
local PILL_W, PILL_H, PILL_TOP = 150, 36, 14  -- ขนาดและตำแหน่งของแคปซูล (Dynamic Island)

Library.Presets = Presets
function Library:SetTheme(nameOrTable)
	local t = type(nameOrTable) == "string" and Presets[nameOrTable] or nameOrTable
	for k, v in pairs(t or {}) do Theme[k] = v end
end

------------------------------------------------------------------ helpers
local function new(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	if parent then inst.Parent = parent end
	return inst
end

local function round(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function stroke(color, th)
	return new("UIStroke", { Color = color or Theme.Line, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function pad(l, t, r, b)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b),
	})
end
-- ไล่สี Accent → Accent2
local function grad(parent, rotation)
	return new("UIGradient", { Color = ColorSequence.new(Theme.Accent, Theme.Accent2), Rotation = rotation or 0, Parent = parent })
end
-- เส้นคั่น: จางหายที่ปลายทั้งสองข้าง (+ ประกายสีบางๆ ตรงกลางถ้า glint = true)
local function makeDivider(parent, props, glint, vertical)
	local kp = NumberSequenceKeypoint.new
	local d = new("Frame", {
		Size = vertical and UDim2.new(0, 1, 1, 0) or UDim2.new(1, 0, 0, 1),
		BackgroundTransparency = 1, BorderSizePixel = 0,
	})
	for k, v in pairs(props or {}) do d[k] = v end
	local rot = vertical and 90 or 0
	new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Line, BorderSizePixel = 0, Parent = d,
	}, { new("UIGradient", { Rotation = rot, Transparency = NumberSequence.new({ kp(0, 1), kp(0.15, 0.15), kp(0.85, 0.15), kp(1, 1) }) }) })
	if glint then
		new("Frame", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = d,
		}, { new("UIGradient", {
			Rotation = rot, Color = ColorSequence.new(Theme.Accent, Theme.Accent2),
			Transparency = NumberSequence.new({ kp(0, 1), kp(0.3, 1), kp(0.5, 0.45), kp(0.7, 1), kp(1, 1) }),
		}) })
	end
	d.Parent = parent
	return d
end
local function listLayout(padding)
	return new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, padding or 0) })
end
local function tween(inst, props, t)
	TweenService:Create(inst, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function label(props)
	local p = {
		BackgroundTransparency = 1, Font = Theme.Font, TextColor3 = Theme.Text,
		TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
	}
	for k, v in pairs(props) do p[k] = v end
	return new("TextLabel", p)
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end
local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

-- ===== ไอคอน: รองรับ emoji/ข้อความ, รูปภาพ และตัวละครของผู้เล่น Roblox =====
-- รูปแบบ Icon ที่ใส่ได้:
--   "📊" หรือ "★"                      → ข้อความ/emoji
--   "rbxassetid://123456"               → รูปภาพ (รวม rbxthumb:// และ https://)
--   "me" / "me:bust" / "me:full"        → ตัวละครของผู้เล่นเอง (หน้า / ครึ่งตัว / เต็มตัว)
--   "avatar:USERID" (":bust" ":full")   → ตัวละครของผู้ใช้ตาม UserId
--   "user:USERNAME" (":bust" ":full")   → ตัวละครของผู้ใช้ตามชื่อ
--   Player instance (เช่น Icon = plr)   → รูปหน้าของผู้เล่นคนนั้น
local thumbCache = {}

local function isImageString(s)
	return s:match("^rbxassetid://") or s:match("^rbxasset://") or s:match("^rbxthumb://") or s:match("^https?://")
end

local function thumbTypeFor(style)
	style = string.lower(style or "")
	if style == "bust" then return Enum.ThumbnailType.AvatarBust end
	if style == "full" or style == "body" then return Enum.ThumbnailType.AvatarThumbnail end
	return Enum.ThumbnailType.HeadShot
end

-- คืนค่า (userId หรือ username, ประเภทรูป) ถ้า icon เป็นรูปแบบตัวละคร
local function parseAvatar(icon)
	if typeof(icon) == "Instance" and icon:IsA("Player") then
		return icon.UserId, Enum.ThumbnailType.HeadShot
	end
	if type(icon) ~= "string" then return nil end
	local head, rest = string.match(icon, "^(%a+):?(.*)$")
	if not head then return nil end
	head = string.lower(head)
	if head == "me" or head == "localplayer" then
		return Players.LocalPlayer.UserId, thumbTypeFor(rest)
	elseif head == "avatar" or head == "user" then
		local who, style = string.match(rest, "^([^:]+):?(.*)$")
		if not who then return nil end
		if head == "avatar" then who = tonumber(who) end
		if who == nil then return nil end
		return who, thumbTypeFor(style)
	end
	return nil
end

local function loadAvatar(img, who, ttype)
	task.spawn(function()
		local key = tostring(who) .. ":" .. tostring(ttype)
		local url = thumbCache[key]
		if not url then
			local ok, res = pcall(function()
				local id = type(who) == "number" and who or Players:GetUserIdFromNameAsync(who)
				return (Players:GetUserThumbnailAsync(id, ttype, Enum.ThumbnailSize.Size150x150))
			end)
			if ok then
				url = res
				thumbCache[key] = url
			end
		end
		if url and img.Parent then img.Image = url end
	end)
end

-- ใส่เนื้อหาไอคอนลงในกล่อง (ล้างของเก่าก่อน)
local function setIconContent(box, icon, size, textColor, radius)
	for _, c in ipairs(box:GetChildren()) do
		if c:GetAttribute("IconContent") then c:Destroy() end
	end
	if icon == nil or icon == "" then return end

	local who, ttype = parseAvatar(icon)
	local node
	if who then
		node = new("ImageLabel", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "",
			ScaleType = Enum.ScaleType.Crop, Parent = box,
		}, { round(radius or 8) })
		loadAvatar(node, who, ttype)
	elseif type(icon) == "string" and isImageString(icon) then
		node = new("ImageLabel", {
			Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.19, 0.19), BackgroundTransparency = 1,
			Image = icon, ScaleType = Enum.ScaleType.Fit, Parent = box,
		})
	elseif type(icon) == "string" then
		node = new("TextLabel", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = icon,
			TextSize = math.floor(size * 0.5), TextColor3 = textColor or Color3.new(1, 1, 1),
			Font = Theme.FontBold, Parent = box,
		})
	end
	if node then node:SetAttribute("IconContent", true) end
end

-- ไอคอนสี่เหลี่ยมมน
local function makeIcon(parent, icon, size, color, textColor)
	local radius = math.floor(size * 0.28)
	local box = new("Frame", {
		Size = UDim2.fromOffset(size, size), BackgroundColor3 = color or Theme.Accent,
		BorderSizePixel = 0, Parent = parent,
	}, { round(radius) })
	setIconContent(box, icon, size, textColor, radius)
	return box
end

------------------------------------------------------------------ window
function Library:CreateWindow(opts)
	opts = opts or {}
	local self = setmetatable({ Tabs = {}, Groups = {}, GroupCount = 0, Current = nil, _conns = {} }, WindowClass)
	local player = Players.LocalPlayer

	local gui = new("ScreenGui", {
		Name = opts.Name or "NovaUI", ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100,
		Parent = opts.Parent or player:WaitForChild("PlayerGui"),
	})
	self.Gui = gui

	-- ขนาดหน้าต่าง: ไม่ใช้ UIScale/CanvasGroup (ทำให้ตัวอักษรเบลอเหมือนภาพแปะ)
	-- แต่ปรับขนาดให้พอดีกับจอ และใช้เลขคู่เพื่อให้ขอบและตัวอักษรคมชัด
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local want = opts.Size or Vector2.new(880, 560)
	local size = Vector2.new(
		math.max(320, math.floor(math.min(want.X, vp.X - 32) / 2) * 2),
		math.max(240, math.floor(math.min(want.Y, vp.Y - 32) / 2) * 2)
	)
	local function screen()
		local a = gui.AbsoluteSize
		if a.X < 2 or a.Y < 2 then a = vp end
		return a
	end
	local function centerPos()
		local a = screen()
		return UDim2.fromOffset(math.floor(a.X / 2), math.floor(a.Y / 2))
	end
	local function pillPosNow()
		local a = screen()
		return UDim2.fromOffset(math.floor(a.X / 2), PILL_TOP + PILL_H / 2)
	end
	self._screen, self._centerPos = screen, centerPos

	-- สถานะเริ่มต้นเป็นแคปซูลกลางบนจอ แล้วขยายออกเป็นหน้าต่าง (Dynamic Island)
	local pillSize = UDim2.fromOffset(PILL_W, PILL_H)
	self._pillSize, self._pillPos = pillSize, pillPosNow()
	self._baseSize = UDim2.fromOffset(size.X, size.Y)
	self._openSize, self._openPos = self._baseSize, centerPos()
	self._centered = true
	self.IsOpen = false

	local main = new("Frame", {
		Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = self._pillPos, Size = pillSize,
		BackgroundColor3 = Theme.Background, BorderSizePixel = 0, ClipsDescendants = true, Parent = gui,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, PILL_H / 2) }),
		-- ไล่เฉดเทาบางๆ ให้พื้นหลังมีมิติ (ไม่มีสี)
		new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(185, 185, 185)), Rotation = 90 }),
	})
	self.Main = main
	self._corner = main:FindFirstChildOfClass("UICorner")
	stroke(Theme.Line, 1).Parent = main

	-- จัดกึ่งกลางใหม่เมื่อขนาดจอเปลี่ยน
	self:_track(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self._pillPos = pillPosNow()
		if self._centered then self._openPos = centerPos() end
		main.Position = self.IsOpen and self._openPos or self._pillPos
	end))

	-- ผิวของแคปซูล (โลโก้ + ชื่อ) แสดงตอนพับ จางหายตอนขยาย
	local cover = new("Frame", {
		Name = "Island", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0, ZIndex = 100, Parent = main,
	}, { new("UICorner", { CornerRadius = UDim.new(0, PILL_H / 2) }) })
	self._cover = cover
	self._coverCorner = cover:FindFirstChildOfClass("UICorner")
	local face = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(124, 24), BackgroundTransparency = 1, Parent = cover,
	})
	local faceLogo = makeIcon(face, opts.Logo or "◈", 22, Color3.new(1, 1, 1), Theme.AccentText)
	faceLogo.Position = UDim2.fromOffset(0, 1)
	grad(faceLogo, 45)
	label({
		Text = (opts.Title or "NovaUI") .. (opts.Version and (" " .. opts.Version) or ""),
		Font = Theme.FontBold, TextSize = 17, Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -30, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = face,
	})
	-- รายการที่ต้องไล่ความโปร่งใสตอนเปิด/ปิด (แทน CanvasGroup)
	self._fade = { { cover, "BackgroundTransparency" } }
	for _, d in ipairs(face:GetDescendants()) do
		if d:IsA("TextLabel") then table.insert(self._fade, { d, "TextTransparency" })
		elseif d:IsA("ImageLabel") then table.insert(self._fade, { d, "ImageTransparency" })
		elseif d:IsA("Frame") then table.insert(self._fade, { d, "BackgroundTransparency" }) end
	end
	local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5, Parent = cover })
	hit.MouseButton1Click:Connect(function() self:Open() end)

	-- เลเยอร์สำหรับหน้าต่างเลือกแบบ popup (อยู่เหนือเนื้อหา ใต้ผิวแคปซูล)
	local layer = new("Frame", { Name = "Layer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 90, Visible = false, Parent = main })
	local backdrop = new("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
		Text = "", AutoButtonColor = false, ZIndex = 90, Parent = layer,
	}, { round(12) })
	self._layer, self._backdrop, self._activePicker = layer, backdrop, nil
	backdrop.MouseButton1Click:Connect(function()
		if self._activePicker then self._activePicker.Close() end
	end)

	-- กล่องแจ้งเตือน (มุมล่างขวาของจอ ซ้อนกันขึ้นด้านบน)
	self._toasts, self._toastOrder = {}, 0
	self._toastHolder = new("Frame", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.new(0, 320, 1, -40),
		BackgroundTransparency = 1, Parent = gui,
	}, { new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right,
	}) })


	-- tooltip ชื่อแท็บ (อยู่นอก main เพื่อไม่โดนตัด)
	local tip = new("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = Theme.Raised,
		BorderSizePixel = 0, Visible = false, ZIndex = 50, Parent = gui,
	}, { round(6), stroke(Theme.Line), pad(10, 6, 10, 6) })
	local tipLabel = label({
		AutomaticSize = Enum.AutomaticSize.XY, TextSize = 15, ZIndex = 51, Parent = tip,
	})
	function self:_showTip(target, text)
		tipLabel.Text = text
		tip.Position = UDim2.fromOffset(
			target.AbsolutePosition.X + target.AbsoluteSize.X + 10,
			target.AbsolutePosition.Y + target.AbsoluteSize.Y / 2 - 16
		)
		tip.Visible = true
	end
	function self:_hideTip() tip.Visible = false end

	-- แถบไอคอนซ้าย ------------------------------------------------------
	local rail = new("Frame", {
		Size = UDim2.new(0, RAIL_W, 1, 0), BackgroundTransparency = 1, ClipsDescendants = true, Parent = main,
	})
	-- พื้นแถบซ้าย: กว้างเกินแล้วโดนตัด เพื่อให้มีเฉพาะมุมซ้ายที่โค้งตามหน้าต่าง
	new("Frame", {
		Name = "RailBg", Size = UDim2.new(1, 24, 1, 0), BackgroundColor3 = Theme.Rail, BorderSizePixel = 0, ZIndex = 0, Parent = rail,
	}, { round(12) })
	self._rail = rail
	makeDivider(rail, { Position = UDim2.new(1, -1, 0, 0) }, false, true)

	-- โลโก้ (บนสุด ไม่เลื่อน)
	local logoHolder = new("TextButton", { Size = UDim2.new(1, 0, 0, 68), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = rail })
	local logo = makeIcon(logoHolder, opts.Logo or "◈", 38, Theme.Accent, Theme.AccentText)
	logo.BackgroundColor3 = Color3.new(1, 1, 1)
	grad(logo, 45)
	logo.AnchorPoint = Vector2.new(0.5, 0.5)
	logo.Position = UDim2.new(0.5, 0, 0.5, 2)
	logoHolder.MouseEnter:Connect(function()
		self:_showTip(logoHolder, (opts.Title or "NovaUI") .. (opts.Version and (" " .. opts.Version) or ""))
	end)
	logoHolder.MouseLeave:Connect(function() self:_hideTip() end)

	-- หมวดหมู่ (เลื่อนได้)
	local nav = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 1, -132),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ElasticBehavior = Enum.ElasticBehavior.Never,
		Parent = rail,
	}, {
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		pad(0, 0, 1, 8),
	})
	self.Nav = nav

	-- รูปผู้ใช้ (ล่างสุด ไม่เลื่อน)
	local user = new("TextButton", { Size = UDim2.new(1, 0, 0, 64), Position = UDim2.new(0, 0, 1, -64), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = rail })
	makeDivider(user, { Size = UDim2.new(1, -1, 0, 1) })
	local avatar = new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Theme.Raised, BorderSizePixel = 0, Parent = user,
	}, { round(18) })
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok then avatar.Image = img end
	end)
	user.MouseEnter:Connect(function() self:_showTip(user, player.DisplayName) end)
	user.MouseLeave:Connect(function() self:_hideTip() end)

	-- ฝั่งขวา ------------------------------------------------------------
	local right = new("Frame", {
		Position = UDim2.fromOffset(RAIL_W, 0), Size = UDim2.new(1, -RAIL_W, 1, 0),
		BackgroundTransparency = 1, ClipsDescendants = true, Parent = main,
	})
	self.Right = right
	rail.Visible, right.Visible = false, false -- ซ่อนจนกว่าจะขยายออกจากแคปซูล

	local header = new("Frame", { Size = UDim2.new(1, 0, 0, HEADER_H), BackgroundTransparency = 1, Parent = right })
	self._header = header
	makeDivider(header, { Position = UDim2.new(0, 0, 1, -1) }, true)
	self.TitleLabel = label({
		Font = Theme.FontBold, TextSize = 20, Position = UDim2.fromOffset(20, 8), Size = UDim2.new(1, -150, 0, 24),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = header,
	})
	self.GroupLabel = label({
		TextColor3 = Theme.Muted, TextSize = 14, Position = UDim2.fromOffset(20, 33), Size = UDim2.new(1, -150, 0, 18),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = header,
	})

	local controls = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = header,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local function ctrl(glyph, order, hoverColor)
		local b = new("TextButton", {
			Size = UDim2.fromOffset(28, 28), BackgroundColor3 = hoverColor, BackgroundTransparency = 1,
			Text = glyph, Font = Theme.Font, TextSize = 16, TextColor3 = Theme.Muted,
			AutoButtonColor = false, LayoutOrder = order, Parent = controls,
		}, { round(7) })
		b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0.15 }) b.TextColor3 = Theme.Text end)
		b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = 1 }) b.TextColor3 = Theme.Muted end)
		return b
	end
	local minBtn = ctrl("–", 1, Theme.Raised)
	local maxBtn = ctrl("▢", 2, Theme.Raised)
	local closeBtn = ctrl("✕", 3, Theme.Danger)

	-- เหตุการณ์ของหน้าต่าง -------------------------------------------------
	closeBtn.MouseButton1Click:Connect(function() self:Destroy() end)
	minBtn.MouseButton1Click:Connect(function() self:Toggle() end)

	local maximized = false
	maxBtn.MouseButton1Click:Connect(function()
		if not self.IsOpen then return end
		maximized = not maximized
		local a = self._screen()
		self._openSize = maximized
			and UDim2.fromOffset(math.floor((a.X - 40) / 2) * 2, math.floor((a.Y - 40) / 2) * 2)
			or self._baseSize
		self._openPos = self._centerPos()
		self._centered = true
		tween(main, { Size = self._openSize, Position = self._openPos }, 0.25)
	end)

	-- ลากหน้าต่างจากแถบหัว
	local dragging, dragStart, startPos = false, nil, nil
	header.InputBegan:Connect(function(input)
		if isPress(input) and self.IsOpen then
			dragging, dragStart, startPos = true, input.Position, main.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	self:_track(UserInputService.InputChanged:Connect(function(input)
		if dragging and isMove(input) then
			local d = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + math.floor(d.X), startPos.Y.Scale, startPos.Y.Offset + math.floor(d.Y))
			self._openPos = main.Position
			self._centered = false
		end
	end))

	-- ปุ่มลัดซ่อน/แสดง
	local key = opts.ToggleKey or Enum.KeyCode.RightShift
	self:_track(UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == key then self:Toggle() end
	end))

	-- เปิดตัวด้วยแอนิเมชันขยายจากแคปซูล
	task.delay(0.15, function()
		if self.Gui.Parent then self:Open() end
	end)

	return self
end

function WindowClass:_track(conn) table.insert(self._conns, conn) return conn end
-- แจ้งเตือน: Window:Notify({ Title, Content, Type = "info"|"success"|"warning"|"error", Duration = 4, Icon, Callback })
-- Duration = 0 คือค้างไว้จนกว่าจะกด | ใส่เป็นข้อความอย่างเดียวก็ได้ เช่น Window:Notify("Saved!")
function WindowClass:Notify(o)
	o = type(o) == "string" and { Title = o } or (o or {})
	local kind = o.Type or "info"
	local tint = ({ success = Theme.Ready, warning = Theme.Warning, error = Theme.Danger })[kind] -- info = สีไล่เฉดของธีม
	local glyph = ({ info = "i", success = "✓", warning = "!", error = "✕" })[kind] or "i"
	local duration = o.Duration == nil and 4 or o.Duration

	while #self._toasts >= 5 do self._toasts[1].Close() end -- แสดงพร้อมกันสูงสุด 5 อัน

	self._toastOrder += 1
	local wrapper = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		LayoutOrder = self._toastOrder, Parent = self._toastHolder,
	})
	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(1, 60, 0, 0),
		BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Parent = wrapper,
	}, { round(12), stroke(Theme.Line), new("UISizeConstraint", { MinSize = Vector2.new(0, 60) }) })

	local body = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = card,
	}, { pad(58, 12, 36, 16), listLayout(3) })
	label({
		Text = o.Title or "Notification", Font = Theme.FontBold, TextSize = 16, TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 1, Parent = body,
	})
	if o.Content and o.Content ~= "" then
		label({
			Text = o.Content, TextColor3 = Theme.Muted, TextSize = 15, TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2, Parent = body,
		})
	end

	local icon = makeIcon(card, o.Icon or glyph, 32, tint or Color3.new(1, 1, 1), tint and Color3.new(1, 1, 1) or Theme.AccentText)
	icon.Position = UDim2.fromOffset(14, 14)
	if not tint then grad(icon, 45) end
	label({
		Text = "✕", TextColor3 = Theme.Muted, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 12), Size = UDim2.fromOffset(16, 16), Parent = card,
	})

	local bar
	if duration > 0 then
		bar = new("Frame", {
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -1), Size = UDim2.new(1, -28, 0, 2),
			BackgroundColor3 = tint or Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = card,
		}, { round(1) })
		if not tint then grad(bar, 0) end
	end

	local handle = {}
	local closed = false
	function handle.Close()
		if closed then return end
		closed = true
		local i = table.find(self._toasts, handle)
		if i then table.remove(self._toasts, i) end
		TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 60, 0, 0),
		}):Play()
		task.delay(0.26, function()
			if not wrapper.Parent then return end
			wrapper.AutomaticSize = Enum.AutomaticSize.None
			wrapper.Size = UDim2.new(1, 0, 0, wrapper.AbsoluteSize.Y)
			tween(wrapper, { Size = UDim2.new(1, 0, 0, 0) }, 0.2)
			task.delay(0.22, function() wrapper:Destroy() end)
		end)
	end
	table.insert(self._toasts, handle)

	-- กดที่แจ้งเตือน = ปิด (และเรียก Callback ถ้ามี)
	local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5, Parent = card })
	hit.MouseButton1Click:Connect(function()
		if o.Callback then task.spawn(o.Callback) end
		handle.Close()
	end)

	TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 0, 0) }):Play()
	if bar then
		TweenService:Create(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()
		task.delay(duration, handle.Close)
	end
	return handle
end

-- ไล่ความโปร่งใสของผิวแคปซูล (0 = ทึบ, 1 = จางหาย)
function WindowClass:_fadeCover(to, info)
	for _, t in ipairs(self._fade) do
		TweenService:Create(t[1], info, { [t[2]] = to }):Play()
	end
end

-- ขยายจากแคปซูลเป็นหน้าต่าง (สปริงเด้งนิดๆ แบบ Dynamic Island)
function WindowClass:Open()
	if self.IsOpen then return end
	self.IsOpen = true
	self._cover.Visible = true
	self._rail.Visible, self.Right.Visible = true, true
	TweenService:Create(self.Main, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = self._openSize, Position = self._openPos,
	}):Play()
	local cornerInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(self._corner, cornerInfo, { CornerRadius = UDim.new(0, 12) }):Play()
	TweenService:Create(self._coverCorner, cornerInfo, { CornerRadius = UDim.new(0, 12) }):Play()
	self:_fadeCover(1, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.12))
	task.delay(0.45, function()
		if self.IsOpen then self._cover.Visible = false end
	end)
end

-- พับกลับเป็นแคปซูลที่กลางบนจอ (กดที่แคปซูลหรือ RightShift เพื่อเปิดอีกครั้ง)
function WindowClass:Close()
	if not self.IsOpen then return end
	self.IsOpen = false
	self:_hideTip()
	if self._activePicker then self._activePicker.Close(true) end
	self._layer.Visible = false
	self._cover.Visible = true
	self:_fadeCover(0, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	TweenService:Create(self.Main, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {
		Size = self._pillSize, Position = self._pillPos,
	}):Play()
	local cornerInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
	TweenService:Create(self._corner, cornerInfo, { CornerRadius = UDim.new(0, PILL_H / 2) }):Play()
	TweenService:Create(self._coverCorner, cornerInfo, { CornerRadius = UDim.new(0, PILL_H / 2) }):Play()
	-- ซ่อนเนื้อหาหลังผิวแคปซูลทึบแล้ว กันมุมเหลี่ยมโผล่ตอนเป็นแคปซูล
	task.delay(0.22, function()
		if not self.IsOpen then self._rail.Visible, self.Right.Visible = false, false end
	end)
end

function WindowClass:Toggle()
	if self.IsOpen then self:Close() else self:Open() end
end
function WindowClass:Destroy()
	for _, c in ipairs(self._conns) do c:Disconnect() end
	self.Gui:Destroy()
end

function WindowClass:SelectTab(tab)
	if type(tab) == "string" then tab = self.Tabs[tab] end
	if not tab then return end
	local cur = self.Current
	if cur then
		cur.Page.Visible = false
		tween(cur.Button, { BackgroundTransparency = 0.82 })
		cur.Indicator.Visible = false
	end
	self.Current = tab
	tab.Page.Visible = true
	tween(tab.Button, { BackgroundTransparency = 0 })
	tab.Indicator.Visible = true
	self.TitleLabel.Text = tab.Name
	self.GroupLabel.Text = tab.Group

	-- ไอคอนของแท็บที่หัวหน้าต่าง
	if self._titleIcon then self._titleIcon:Destroy() self._titleIcon = nil end
	local x = 20
	if tab.Icon and tab.Icon ~= "" then
		local ic = makeIcon(self._header, tab.Icon, 30, tab.Color or Theme.Accent)
		ic.Position = UDim2.fromOffset(18, 15)
		self._titleIcon = ic
		x = 58
	end
	self.TitleLabel.Position = UDim2.fromOffset(x, 8)
	self.GroupLabel.Position = UDim2.fromOffset(x, 33)
end

------------------------------------------------------------------ tabs
function WindowClass:AddTab(o)
	o = o or {}
	local window = self
	local groupName = o.Group or "General"

	local g = self.Groups[groupName]
	if not g then
		self.GroupCount += 1
		g = { Order = self.GroupCount * 1000, Count = 0 }
		self.Groups[groupName] = g
		-- เส้นคั่นหมวด (ไม่ต้องมีก่อนหมวดแรก)
		local sep = new("Frame", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, LayoutOrder = g.Order, Parent = self.Nav })
		if self.GroupCount > 1 then
			new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(22, 1), BackgroundColor3 = Theme.Line, BorderSizePixel = 0, Parent = sep,
			})
		end
	end
	g.Count += 1

	local color = o.Color or Theme.Accent
	local btn = new("TextButton", {
		Size = UDim2.fromOffset(44, 44), BackgroundColor3 = color, BackgroundTransparency = 0.82,
		Text = "", AutoButtonColor = false, LayoutOrder = g.Order + g.Count, Parent = self.Nav,
	}, { round(12) })
	setIconContent(btn, o.Icon, 44, Color3.new(1, 1, 1), 12)
	local indicator = new("Frame", {
		Position = UDim2.new(0, -10, 0.5, -12), Size = UDim2.fromOffset(3, 24),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Visible = false, Parent = btn,
	}, { round(2) })
	grad(indicator, 90)

	local page = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, HEADER_H), Size = UDim2.new(1, 0, 1, -HEADER_H),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Line, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = self.Right,
	}, { listLayout(16), pad(18, 16, 18, 18) })

	local tab = setmetatable({
		Window = window, Name = o.Name or "Tab", Group = groupName, Icon = o.Icon, Color = o.Color,
		Page = page, Button = btn, Indicator = indicator, Order = 0,
	}, TabClass)
	self.Tabs[tab.Name] = tab

	btn.MouseButton1Click:Connect(function() window:SelectTab(tab) end)
	btn.MouseEnter:Connect(function()
		window:_showTip(btn, tab.Name)
		if window.Current ~= tab then tween(btn, { BackgroundTransparency = 0.6 }) end
	end)
	btn.MouseLeave:Connect(function()
		window:_hideTip()
		if window.Current ~= tab then tween(btn, { BackgroundTransparency = 0.82 }) end
	end)

	if not self.Current then self:SelectTab(tab) end
	return tab
end

------------------------------------------------------------------ sections
function TabClass:AddSection(o)
	o = o or {}
	self.Order += 1

	local holder = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, LayoutOrder = self.Order, Parent = self.Page,
	}, { listLayout(10) })

	if o.Title then
		local head = new("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, LayoutOrder = 1, Parent = holder })
		local x = 14
		if o.Icon then
			-- ไอคอนหัวข้อ (ใส่ Color เองได้ ถ้าไม่ใส่จะเป็นสีไล่เฉดของธีม)
			local ic = makeIcon(head, o.Icon, 34, o.Color or Color3.new(1, 1, 1), o.Color and Color3.new(1, 1, 1) or Theme.AccentText)
			ic.Position = UDim2.fromOffset(0, 2)
			if not o.Color then grad(ic, 45) end
			x = 46
		else
			local stripe = new("Frame", {
				Position = UDim2.fromOffset(0, 3), Size = UDim2.fromOffset(3, 34),
				BackgroundColor3 = o.Color or Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = head,
			}, { round(2) })
			if not o.Color then grad(stripe, 90) end
		end
		label({ Text = o.Title, Font = Theme.FontBold, TextSize = 18, Position = UDim2.fromOffset(x, 3), Size = UDim2.new(1, -x, 0, 20), Parent = head })
		label({ Text = o.Description or "", TextColor3 = Theme.Muted, TextSize = 14, Position = UDim2.fromOffset(x, 23), Size = UDim2.new(1, -x, 0, 18), Parent = head })
	end

	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0, ClipsDescendants = true, LayoutOrder = 2, Parent = holder,
	}, { round(10), listLayout(0), new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215)), Rotation = 90 }) })

	return setmetatable({ Card = card, N = 0, Window = self.Window }, SectionClass)
end

-- กล่องของ element หนึ่งอัน (พร้อมเส้นคั่นด้านบนถ้าไม่ใช่อันแรก)
local function newElement(section)
	section.N += 1
	local order = section.N * 2
	if section.N > 1 then
		makeDivider(section.Card, { LayoutOrder = order - 1 }, true)
	end
	return new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, LayoutOrder = order, Parent = section.Card,
	}, { listLayout(0) })
end

local function makeRow(el, title, desc, rightWidth)
	local hasDesc = desc ~= nil and desc ~= ""
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, hasDesc and 66 or 54), BackgroundTransparency = 1, LayoutOrder = 1, Parent = el })
	local t = label({
		Text = title or "", TextSize = 16,
		Position = UDim2.fromOffset(16, hasDesc and 11 or 16), Size = UDim2.new(1, -(rightWidth + 32), 0, 22),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
	})
	if hasDesc then
		label({
			Text = desc, TextColor3 = Theme.Muted, TextSize = 14,
			Position = UDim2.fromOffset(16, 35), Size = UDim2.new(1, -(rightWidth + 32), 0, 20),
			TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
		})
	end
	return row, t
end

------------------------------------------------------------------ label
function SectionClass:AddLabel(text)
	local el = newElement(self)
	local _, t = makeRow(el, text, nil, 0)
	t.TextColor3 = Theme.Muted
	local obj = {}
	function obj:Set(s) t.Text = s end
	return obj
end

------------------------------------------------------------------ button
function SectionClass:AddButton(o)
	local el = newElement(self)
	local row = makeRow(el, o.Title, o.Description, 110)
	local btn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(100, 34),
		BackgroundColor3 = Color3.new(1, 1, 1), Text = o.ButtonText or "Run", Font = Theme.FontBold,
		TextSize = 15, TextColor3 = Theme.AccentText, AutoButtonColor = false, Parent = row,
	}, { round(8) })
	grad(btn, 0)
	btn.MouseEnter:Connect(function() tween(btn, { BackgroundTransparency = 0.2 }) end)
	btn.MouseLeave:Connect(function() tween(btn, { BackgroundTransparency = 0 }) end)
	btn.MouseButton1Click:Connect(function()
		if o.Callback then task.spawn(o.Callback) end
	end)
	return btn
end

------------------------------------------------------------------ toggle (OFF | ON)
function SectionClass:AddToggle(o)
	local el = newElement(self)
	local row = makeRow(el, o.Title, o.Description, 98)
	local state = o.Default and true or false

	local seg = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(86, 30),
		BackgroundColor3 = Theme.Off, Text = "", AutoButtonColor = false, Parent = row,
	}, { round(8) })
	local thumb = new("Frame", {
		Position = UDim2.new(0, 3, 0, 3), Size = UDim2.new(0.5, -3, 1, -6),
		BackgroundColor3 = Theme.Raised, BorderSizePixel = 0, Parent = seg,
	}, { round(6) })
	local offLabel = label({ Text = "OFF", Font = Theme.FontNumber, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(0.5, 0, 1, 0), ZIndex = 2, Parent = seg })
	local onLabel = label({ Text = "ON", Font = Theme.FontNumber, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0.5, 0, 1, 0), ZIndex = 2, Parent = seg })

	local thumbGrad = grad(thumb)
	local function paint(v, instant)
		local props = {
			Position = v and UDim2.new(0.5, 0, 0, 3) or UDim2.new(0, 3, 0, 3),
			BackgroundColor3 = v and Color3.new(1, 1, 1) or Theme.Raised,
		}
		thumbGrad.Enabled = v
		if instant then for k, val in pairs(props) do thumb[k] = val end else tween(thumb, props) end
		onLabel.TextColor3 = v and Theme.AccentText or Theme.Muted
		offLabel.TextColor3 = v and Theme.Muted or Theme.Text
	end
	paint(state, true)

	local obj = {}
	local function apply(v, silent)
		state = v
		paint(v)
		if not silent and o.Callback then task.spawn(o.Callback, v) end
	end
	function obj:Set(v) apply(v and true or false) end
	function obj:Get() return state end
	seg.MouseButton1Click:Connect(function() apply(not state) end)

	if o.Default ~= nil and o.Callback then task.defer(o.Callback, state) end
	return obj
end

------------------------------------------------------------------ slider
function SectionClass:AddSlider(o)
	local window = self.Window
	local el = newElement(self)
	local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
	local value = math.clamp(o.Default or min, min, max)

	local row = makeRow(el, o.Title, o.Description, 90)
	local bubble = new("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, o.Description and o.Description ~= "" and 16 or 13),
		Size = UDim2.fromOffset(68, 28), BackgroundColor3 = Theme.Raised, BorderSizePixel = 0, Parent = row,
	}, { round(6) })
	local valueLabel = label({
		TextColor3 = Theme.Accent2, Font = Theme.FontNumber, TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = bubble,
	})

	local area = new("TextButton", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 2, Parent = el })
	local bar = new("Frame", {
		Position = UDim2.new(0, 16, 0, 2), Size = UDim2.new(1, -32, 0, 8),
		BackgroundColor3 = Theme.Off, BorderSizePixel = 0, Parent = area,
	}, { round(4) })
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = bar }, { round(4) })
	grad(fill)
	local grip = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 18), Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2, Parent = bar,
	}, { round(3) })

	local function render()
		local rel = (value - min) / math.max(max - min, 1e-9)
		fill.Size = UDim2.fromScale(rel, 1)
		grip.Position = UDim2.fromScale(rel, 0.5)
		valueLabel.Text = tostring(value) .. (o.Suffix or "")
	end

	local obj = {}
	function obj:Set(v)
		v = math.clamp(math.floor((v - min) / step + 0.5) * step + min, min, max)
		v = math.round(v * 1000) / 1000
		if v ~= value then
			value = v
			render()
			if o.Callback then task.spawn(o.Callback, value) end
		end
	end
	function obj:Get() return value end

	local function fromX(x)
		local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		obj:Set(min + (max - min) * rel)
	end
	local dragging = false
	area.InputBegan:Connect(function(input)
		if isPress(input) then dragging = true fromX(input.Position.X) end
	end)
	window:_track(UserInputService.InputChanged:Connect(function(input)
		if dragging and isMove(input) then fromX(input.Position.X) end
	end))
	window:_track(UserInputService.InputEnded:Connect(function(input)
		if isPress(input) then dragging = false end
	end))

	render()
	if o.Default ~= nil and o.Callback then task.defer(o.Callback, value) end
	return obj
end

------------------------------------------------------------------ dropdown (ชิป)
local function normalize(list)
	local out, map = {}, {}
	for _, item in ipairs(list or {}) do
		local opt
		if type(item) == "string" then
			opt = { Name = item }
		else
			opt = { Name = item.Name, Icon = item.Icon, Right = item.Right, Highlight = item.Highlight }
		end
		table.insert(out, opt)
		map[opt.Name] = opt
	end
	return out, map
end

local function rightText(opt)
	if not opt.Right or opt.Right == "" then return "" end
	return opt.Highlight and ("● " .. opt.Right) or opt.Right
end

function SectionClass:AddDropdown(o)
	local window = self.Window
	local el = newElement(self)
	-- Max: 1 = เลือกได้อันเดียว | N = เลือกได้สูงสุด N อัน | 0 หรือ Multi = true = ไม่จำกัด
	local maxSel = o.Max
	if maxSel == nil then maxSel = o.Multi and 0 or 1 end
	local multi = maxSel ~= 1
	local row = makeRow(el, o.Title, o.Description, 280)

	local options, byName = normalize(o.Options)
	local usePopup = o.Popup
	if usePopup == nil then usePopup = #options > 6 end -- รายการยาวๆ เปิดเป็นหน้าต่างเลือกแยกอัตโนมัติ
	local selected = {}
	local obj = {}
	local isOpen = false
	local picker = nil

	local function countSel()
		local n = 0
		for _ in pairs(selected) do n += 1 end
		return n
	end
	local function isFull() return multi and maxSel > 0 and countSel() >= maxSel end

	-- ช่องเลือก ---------------------------------------------------------
	local field = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(264, 42),
		BackgroundColor3 = Theme.Field, Text = "", AutoButtonColor = false, Parent = row,
	}, { round(8), stroke() })
	local fieldStroke = field:FindFirstChildOfClass("UIStroke")
	local text = label({
		Text = "", Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -44, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = field,
	})
	local chev = label({
		Text = "▾", TextColor3 = Theme.Muted, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -18, 0.5, 0), Size = UDim2.fromOffset(24, 42), Parent = field,
	})
	local chipBox, clear
	if multi then
		chipBox = new("Frame", {
			Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -66, 1, 0), BackgroundTransparency = 1,
			ClipsDescendants = true, Visible = false, Parent = field,
		}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
		clear = new("TextButton", {
			Text = "✕", Font = Theme.Font, TextSize = 14, TextColor3 = Theme.Muted, BackgroundTransparency = 1,
			Size = UDim2.fromOffset(22, 42), Position = UDim2.new(1, -50, 0, 0), Parent = field,
		})
	end

	-- รายการแบบกางในการ์ด (ใช้กับรายการสั้นๆ) -----------------------------
	local divider = makeDivider(el, { LayoutOrder = 2, Visible = false })
	local listFrame = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Line, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, LayoutOrder = 3, Parent = el,
	})
	local layout = listLayout(0)
	layout.Parent = listFrame
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		listFrame.Size = UDim2.new(1, 0, 0, math.min(layout.AbsoluteContentSize.Y, 276))
	end)

	local function getValue()
		if multi then
			local arr = {}
			for _, opt in ipairs(options) do if selected[opt.Name] then table.insert(arr, opt.Name) end end
			return arr
		end
		for _, opt in ipairs(options) do if selected[opt.Name] then return opt.Name end end
		return nil
	end

	local function fire()
		if o.Callback then task.spawn(o.Callback, getValue()) end
	end

	local function renderChips(names)
		for _, c in ipairs(chipBox:GetChildren()) do
			if c:IsA("TextLabel") then c:Destroy() end
		end
		local function chip(txt, color, order)
			new("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), BackgroundColor3 = Theme.Raised,
				Text = txt, TextColor3 = color or Theme.Text, Font = Theme.Font, TextSize = 14,
				TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = order, Parent = chipBox,
			}, { round(6), pad(8, 0, 8, 0), new("UISizeConstraint", { MaxSize = Vector2.new(170, 26) }) })
		end
		chip(names[1], nil, 1)
		if #names > 1 then chip("+" .. (#names - 1), Theme.Accent2, 2) end
	end

	local function refresh()
		local names = {}
		local full = isFull()
		for _, opt in ipairs(options) do
			local on = selected[opt.Name] == true
			if on then table.insert(names, opt.Name) end
			if opt.Button then
				opt.Button.BackgroundTransparency = on and 0.4 or 1
				opt.NameLabel.TextColor3 = on and Theme.Text or Theme.Muted
				opt.NameLabel.TextTransparency = (full and not on) and 0.5 or 0
				opt.Tick.Visible = on
			end
		end
		if multi then
			chipBox.Visible = #names > 0
			if #names > 0 then renderChips(names) end
		end
		text.Visible = not (multi and #names > 0)
		if #names == 0 then
			text.Text = o.Placeholder or "Select"
			text.TextColor3 = Theme.Muted
		else
			text.Text = names[1]
			text.TextColor3 = Theme.Text
		end
		if picker then picker.Refresh() end
	end

	local function setOpen(v)
		isOpen = v
		listFrame.Visible = v
		divider.Visible = v
		tween(chev, { Rotation = v and 180 or 0 })
	end

	-- เลือกเกินจำนวนที่กำหนด: ช่องเลือกกะพริบแดงสั้นๆ (หรือตัวนับในหน้าต่างเลือก)
	local flashToken = 0
	local function flashLimit()
		if picker and picker.IsOpen() then picker.Flash() return end
		flashToken += 1
		local my = flashToken
		fieldStroke.Color = Theme.Danger
		task.delay(0.4, function()
			if my == flashToken then fieldStroke.Color = Theme.Line end
		end)
	end

	local function pick(name)
		if not multi then
			selected = { [name] = true }
			setOpen(false)
			if picker then picker.Close() end
		elseif selected[name] then
			selected[name] = nil
		else
			if isFull() then flashLimit() return end
			selected[name] = true
		end
		refresh()
		fire()
	end

	local function buildInline()
		for _, c in ipairs(listFrame:GetChildren()) do
			if c:IsA("GuiButton") then c:Destroy() end
		end
		for i, opt in ipairs(options) do
			local b = new("TextButton", {
				Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = Theme.Raised, BackgroundTransparency = 1,
				Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = listFrame,
			})
			if i > 1 then
				makeDivider(b)
			end
			opt.Tick = new("Frame", {
				Position = UDim2.new(0, 0, 0.5, -11), Size = UDim2.fromOffset(3, 22),
				BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Visible = false, Parent = b,
			}, { round(2), new("UIGradient", { Color = ColorSequence.new(Theme.Accent, Theme.Accent2), Rotation = 90 }) })
			local face = new("Frame", {
				Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(16, 8), BackgroundColor3 = Theme.Raised,
				BorderSizePixel = 0, Parent = b,
			}, { round(15) })
			setIconContent(face, opt.Icon, 30, nil, 15)
			opt.NameLabel = label({
				Text = opt.Name, Position = UDim2.fromOffset(58, 0), Size = UDim2.new(1, -190, 1, 0),
				TextTruncate = Enum.TextTruncate.AtEnd, Parent = b,
			})
			opt.RightLabel = label({
				Text = rightText(opt), Font = Theme.FontNumber, TextSize = 15,
				TextColor3 = opt.Highlight and Theme.Ready or Theme.Muted,
				TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 120, 1, 0), Parent = b,
			})
			opt.Button = b

			b.MouseButton1Click:Connect(function() pick(opt.Name) end)
			b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = selected[opt.Name] and 0.3 or 0.7 }) end)
			b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = selected[opt.Name] and 0.4 or 1 }) end)
		end
		refresh()
	end

	-- หน้าต่างเลือกแยก (popup) สำหรับรายการยาวๆ: เลื่อนได้ + ค้นหา + ติ๊กเลือกตามจำนวนที่กำหนด
	local function buildPicker()
		local P = {}
		local layer, backdrop = window._layer, window._backdrop

		local panel = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(400, 400),
			BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Visible = false, ClipsDescendants = true,
			ZIndex = 91, Parent = layer,
		}, { round(14), stroke(Theme.Line), new("UIScale", { Scale = 0.94 }) })
		local scaleObj = panel:FindFirstChildOfClass("UIScale")

		-- หัว: ชื่อ + ตัวนับ + ปุ่มปิด
		local head = new("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = panel })
		label({
			Text = o.Title or "Select", Font = Theme.FontBold, TextSize = 17,
			Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -170, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = head,
		})
		local counter = label({
			Font = Theme.FontNumber, TextSize = 14, TextColor3 = Theme.Accent2, TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -52, 0.5, 0), Size = UDim2.fromOffset(110, 20), Parent = head,
		})
		local closeX = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = Theme.Raised, BackgroundTransparency = 1, Text = "✕", Font = Theme.Font, TextSize = 16,
			TextColor3 = Theme.Muted, AutoButtonColor = false, Parent = head,
		}, { round(7) })
		closeX.MouseEnter:Connect(function() tween(closeX, { BackgroundTransparency = 0 }) end)
		closeX.MouseLeave:Connect(function() tween(closeX, { BackgroundTransparency = 1 }) end)
		makeDivider(panel, { Position = UDim2.fromOffset(0, 51) }, true)

		-- ช่องค้นหา (แสดงเมื่อรายการยาว)
		local hasSearch = #options > 6
		local searchBox
		if hasSearch then
			local sf = new("Frame", {
				Position = UDim2.fromOffset(12, 62), Size = UDim2.new(1, -24, 0, 34), BackgroundColor3 = Theme.Field, BorderSizePixel = 0, Parent = panel,
			}, { round(8), stroke() })
			searchBox = new("TextBox", {
				Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), BackgroundTransparency = 1, Text = "",
				PlaceholderText = "Search...", PlaceholderColor3 = Theme.Muted, TextColor3 = Theme.Text, Font = Theme.Font,
				TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = sf,
			})
		end
		local listTop = hasSearch and 104 or 60

		local list = new("ScrollingFrame", {
			Position = UDim2.fromOffset(0, listTop), Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Line, CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = panel,
		})
		listLayout(0).Parent = list
		local empty = label({
			Text = "No results", TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, listTop), Size = UDim2.new(1, 0, 0, 46), Visible = false, Parent = panel,
		})

		-- ท้าย: Clear / Done (เฉพาะแบบเลือกหลายอัน)
		local footer = new("Frame", {
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 56),
			BackgroundTransparency = 1, Visible = multi, Parent = panel,
		})
		makeDivider(footer)
		local clearBtn = new("TextButton", {
			Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(90, 32), BackgroundTransparency = 1, Text = "Clear",
			Font = Theme.Font, TextSize = 15, TextColor3 = Theme.Muted, AutoButtonColor = false, Parent = footer,
		}, { round(8) })
		local doneBtn = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 12), Size = UDim2.fromOffset(96, 32),
			BackgroundColor3 = Color3.new(1, 1, 1), Text = "Done", Font = Theme.FontBold, TextSize = 15,
			TextColor3 = Theme.AccentText, AutoButtonColor = false, Parent = footer,
		}, { round(8) })
		grad(doneBtn, 0)

		local function relayout()
			local visible = 0
			for _, opt in ipairs(options) do
				if opt.PBtn and opt.PBtn.Visible then visible += 1 end
			end
			local listH = math.min(math.max(visible, 1) * 46, 276)
			list.Size = UDim2.new(1, 0, 0, listH)
			empty.Visible = visible == 0
			local ph = listTop + listH + (multi and 56 or 8)
			panel.Size = UDim2.fromOffset(400, ph + ph % 2)
		end

		local function applyFilter()
			local q = searchBox and string.lower(searchBox.Text) or ""
			for _, opt in ipairs(options) do
				if opt.PBtn then
					opt.PBtn.Visible = q == "" or string.find(string.lower(opt.Name), q, 1, true) ~= nil
				end
			end
			relayout()
		end
		if searchBox then searchBox:GetPropertyChangedSignal("Text"):Connect(applyFilter) end

		function P.Refresh()
			local n = countSel()
			local limited = multi and maxSel > 0
			local full = isFull()
			for _, opt in ipairs(options) do
				if opt.PBtn then
					local on = selected[opt.Name] == true
					opt.PBox.BackgroundColor3 = on and Color3.new(1, 1, 1) or Theme.Field
					opt.PGrad.Enabled = on
					opt.PStroke.Transparency = on and 1 or 0
					opt.PCheck.Visible = on
					opt.PName.TextColor3 = on and Theme.Text or Theme.Muted
					opt.PName.TextTransparency = (full and not on) and 0.5 or 0
					opt.PBtn.BackgroundTransparency = on and 0.5 or 1
				end
			end
			if multi then
				counter.Text = limited and string.format("%d / %d", n, maxSel) or string.format("%d selected", n)
			else
				counter.Text = ""
			end
			counter.TextColor3 = Theme.Accent2
		end

		local flashTok = 0
		function P.Flash()
			flashTok += 1
			local my = flashTok
			counter.Text = "Max " .. maxSel
			counter.TextColor3 = Theme.Danger
			task.delay(0.7, function()
				if my == flashTok then P.Refresh() end
			end)
		end

		function P.Build()
			for _, c in ipairs(list:GetChildren()) do
				if c:IsA("GuiButton") then c:Destroy() end
			end
			for i, opt in ipairs(options) do
				local b = new("TextButton", {
					Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = Theme.Raised, BackgroundTransparency = 1,
					Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = list,
				})
				if i > 1 then
					makeDivider(b)
				end
				-- ช่องติ๊ก (เหลี่ยมมน = เลือกหลายอัน, กลม = เลือกอันเดียว)
				local box = new("Frame", {
					Position = UDim2.fromOffset(16, 13), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = Theme.Field,
					BorderSizePixel = 0, Parent = b,
				}, { round(multi and 6 or 10) })
				local boxStroke = stroke(Theme.Line, 1.5)
				boxStroke.Parent = box
				local boxGrad = grad(box, 45)
				boxGrad.Enabled = false
				local check = label({
					Text = "✓", Font = Theme.FontBold, TextSize = 15, TextColor3 = Theme.AccentText,
					TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Visible = false, Parent = box,
				})
				local face = new("Frame", {
					Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(48, 8), BackgroundColor3 = Theme.Raised,
					BorderSizePixel = 0, Parent = b,
				}, { round(15) })
				setIconContent(face, opt.Icon, 30, nil, 15)
				opt.PName = label({
					Text = opt.Name, Position = UDim2.fromOffset(90, 0), Size = UDim2.new(1, -220, 1, 0),
					TextTruncate = Enum.TextTruncate.AtEnd, Parent = b,
				})
				opt.PRight = label({
					Text = rightText(opt), Font = Theme.FontNumber, TextSize = 15,
					TextColor3 = opt.Highlight and Theme.Ready or Theme.Muted,
					TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 110, 1, 0), Parent = b,
				})
				opt.PBtn, opt.PBox, opt.PGrad, opt.PStroke, opt.PCheck = b, box, boxGrad, boxStroke, check

				b.MouseButton1Click:Connect(function() pick(opt.Name) end)
			end
			applyFilter()
			P.Refresh()
		end

		function P.IsOpen() return window._activePicker == P end

		function P.Open()
			if window._activePicker and window._activePicker ~= P then window._activePicker.Close(true) end
			window._activePicker = P
			layer.Visible = true
			panel.Visible = true
			if searchBox then searchBox.Text = "" end
			applyFilter()
			P.Refresh()
			scaleObj.Scale = 0.94
			tween(backdrop, { BackgroundTransparency = 0.45 }, 0.2)
			TweenService:Create(scaleObj, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end

		function P.Close(instant)
			if window._activePicker ~= P then return end
			window._activePicker = nil
			if instant then
				panel.Visible = false
				backdrop.BackgroundTransparency = 1
				return
			end
			tween(backdrop, { BackgroundTransparency = 1 }, 0.15)
			TweenService:Create(scaleObj, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.96 }):Play()
			task.delay(0.17, function()
				if window._activePicker ~= P then
					panel.Visible = false
					if window._activePicker == nil then layer.Visible = false end
				end
			end)
		end

		closeX.MouseButton1Click:Connect(function() P.Close() end)
		doneBtn.MouseButton1Click:Connect(function() P.Close() end)
		clearBtn.MouseButton1Click:Connect(function() obj:Clear() end)

		P.Build()
		return P
	end

	field.MouseButton1Click:Connect(function()
		if usePopup then
			if not picker then picker = buildPicker() end
			picker.Open()
		else
			setOpen(not isOpen)
		end
	end)
	if clear then clear.MouseButton1Click:Connect(function() obj:Clear() end) end

	-- public API ---------------------------------------------------------
	function obj:Get() return getValue() end
	function obj:Set(value, silent)
		selected = {}
		local list = type(value) == "table" and value or { value }
		local n = 0
		for _, name in ipairs(list) do
			if byName[name] then
				if not multi then selected = { [name] = true } break end
				if maxSel > 0 and n >= maxSel then break end
				selected[name] = true
				n += 1
			end
		end
		refresh()
		if not silent then fire() end
	end
	function obj:SelectAll()
		local all = {}
		for _, opt in ipairs(options) do table.insert(all, opt.Name) end
		obj:Set(all)
	end
	function obj:Clear()
		selected = {}
		refresh()
		fire()
	end
	function obj:Open()
		if usePopup then
			if not picker then picker = buildPicker() end
			picker.Open()
		else
			setOpen(true)
		end
	end
	function obj:Close()
		setOpen(false)
		if picker then picker.Close() end
	end
	function obj:SetOptions(list)
		options, byName = normalize(list)
		for name in pairs(selected) do
			if not byName[name] then selected[name] = nil end
		end
		if not usePopup then buildInline() end
		if picker then picker.Build() end
		refresh()
		fire()
	end
	function obj:SetRight(name, textValue, highlight)
		local opt = byName[name]
		if not opt then return end
		opt.Right, opt.Highlight = textValue, highlight
		local color = highlight and Theme.Ready or Theme.Muted
		if opt.RightLabel then
			opt.RightLabel.Text = rightText(opt)
			opt.RightLabel.TextColor3 = color
		end
		if opt.PRight then
			opt.PRight.Text = rightText(opt)
			opt.PRight.TextColor3 = color
		end
	end

	if usePopup then refresh() else buildInline() end
	if o.Default ~= nil then
		obj:Set(o.Default, true)
		task.defer(fire)
	end
	return obj
end

return Library
