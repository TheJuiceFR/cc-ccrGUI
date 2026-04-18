
local pbg=term.getBackgroundColor()
local pfg=term.getTextColor()
local function msg(...)
	os.queueEvent("debugmsg",...)
end

local scrollwin
local confirm=false

print("syncing...")
ccr.sync(0)

local db=ccr.loaddb()
local ldb=ccr.loadldb()

local function prog()

local shade=string.char(127)
local up=string.char(24)
local down=string.char(25)
local updown=string.char(18)

local t=term.current()
t.setBackgroundColor(colors.lightGray)
t.clear()

local w,h=t.getSize()

scrollwin=window.create(t,1,2,w-1,h-1)

scrollwin.subitems={}

function rebuildItem(self)
	if self.installed then
		if self.selected then
			self.setBackgroundColor(colors.red)
		else
			self.setBackgroundColor(colors.green)
		end
	else
		if self.selected then
			self.setBackgroundColor(colors.blue)
		else
			self.setBackgroundColor(colors.black)
		end
	end
	
	self.clear()
	self.setCursorPos(1,1)
	self.write(self.text)
end

for k,v in pairs(db) do
	local ind=#scrollwin.subitems+1
	local out=window.create(scrollwin,1,ind,w-1,1)
	out.index=ind
	out.text=k
	out.installed=ldb[k]~=nil
	out.selected=false
	out.rebuild=rebuildItem
	scrollwin.subitems[ind]=out
end



scrollwin.position=0
scrollwin.maxscroll=1+#scrollwin.subitems-h
if scrollwin.maxscroll<0 then scrollwin.maxscroll=0 end

function scrollwin.rebuild()
	scrollwin.clear()
	w,h=scrollwin.getSize()
	for k,v in pairs(scrollwin.subitems) do
		v.reposition(1,k-scrollwin.position,w,1)
		v:rebuild()
	end
end

function scrollwin.scrollb(p)
	scrollwin.scroll(-(scrollwin.position-p))
	scrollwin.position=p
	if scrollwin.position<0 then
		scrollwin.position=0
	elseif scrollwin.position>scrollwin.maxscroll then
		scrollwin.position=scrollwin.maxscroll
	end
	
	scrollwin.rebuild()
end

function scrollwin.effect()
	w,h=scrollbar.getSize()
	scrollbar.move(math.floor(((scrollwin.position)/(scrollwin.maxscroll))*(h-2)+.5))
end

function scrollwin.click(button,x,y)
	if button==1 then
		for k,v in pairs(scrollwin.subitems) do
			local wx,wy=v.getPosition()
			if y==wy then
				v.selected=not v.selected
				v:rebuild()
				return
			end
		end
	elseif button==2 then
		for k,v in pairs(scrollwin.subitems) do
			local wx,wy=v.getPosition()
			if y==wy then
				t.clear()
				t.setCursorPos(1,1)
				print(v.text..":")
				if db[v.text] then
					print("version: "..db[v.text].version)
					print("description: ")
					print(db[v.text].description)
					print("")
					if db[v.text].optDepends[1] then
						print("Optional packages: ")
						for k2,v2 in pairs(db[v.text].optDepends) do
							print(v2[1]..": "..v2[2])
						end
					end
				else
					print("'"..v.text"' is not in main database")
				end
				if ldb[v.text] then
					if (db[v.text]==nil or ldb[v.text].version~=db[v.text].version) then
						print("local version: "..ldb[v.text].version)
					else
						print("package is up to date")
					end
				else
					print("package is not installed locally")
				end
				repeat ev=os.pullEvent() until ev=="mouse_click" or ev=="key"
				refresh()
				return
			end
		end
	end
end


scrollbar=window.create(t,w,2,1,h-1)
scrollbar.setBackgroundColor(colors.gray)
scrollbar.position=0
scrollbar.grabbed=false

function scrollbar.rebuild()
	scrollbar.clear()
	w,h=scrollbar.getSize()
	scrollbar.setCursorPos(1,1)
	scrollbar.blit(up,'f','8')
	
	scrollbar.setCursorPos(1,h)
	scrollbar.blit(down,'f','8')
	
	scrollbar.setCursorPos(1,scrollbar.position+2)
	scrollbar.blit(updown,'f','8')
end

function scrollbar.move(p)
	w,h=scrollbar.getSize()
	scrollbar.setCursorPos(1,scrollbar.position+2)
	scrollbar.write(" ")
	scrollbar.position=p
	
	if scrollbar.position<0 then scrollbar.position=0 end
	if scrollbar.position>h-3 then scrollbar.position=h-3 end
	
	scrollbar.setCursorPos(1,scrollbar.position+2)
	scrollbar.blit(updown,'f','8')
end

function scrollbar.affect()
	w,h=scrollbar.getSize()
	scrollwin.scrollb(math.floor((scrollbar.position/(h-3))*scrollwin.maxscroll+.5))
end


w,h=nil,nil


function refresh()
	local w,h=t.getSize()
	t.clear()
	t.setCursorPos(1,1)
	t.write("CCRepo")
	
	t.setCursorPos(w-6,1)
	t.blit("Apply","fffff","ddddd")
	
	t.setCursorPos(w,1)
	t.blit("X","f","e")
	
	scrollwin.reposition(1,2,w-1,h-1)
	scrollbar.reposition(w,2,1,h-1)
	scrollwin.rebuild()
	scrollbar.rebuild()
end
refresh()


repeat
	local w,h=t.getSize()
	event,p1,p2,p3=os.pullEventRaw()
	if event=="mouse_click" then
		if p2==w and p3>1 then	--scrollbar was clicked
			if p3==2 then	--up button
				scrollwin.scrollb(scrollwin.position-(h-1))
				scrollwin.effect()
			elseif p3==h then--down
				scrollwin.scrollb(scrollwin.position+h-1)
				scrollwin.effect()
			else			--slider
				scrollbar.grabbed=true
				scrollbar.move(p3-3)
				scrollbar.affect()
			end
		elseif p2<w and p3>1 then --scrollwindow was clicked
			scrollwin.click(p1,p2,p3-1)
		elseif p3==1 and p2<=w-2 and p2>=w-6 then
			confirm=true
		end
	elseif event=="mouse_up" then
		scrollbar.grabbed=false
	elseif event=="mouse_drag" then
		scrollbar.move(p3-3)
		scrollbar.affect()
	elseif event=="term_resize" then
		refresh()
	end
	
until (event=="mouse_click" and p2==w and p3==1) or confirm or event=="terminate"

end

res={pcall(prog)}
if res[1]==false then msg("ERROR: CCRGui:",res[2]) end

term.setBackgroundColor(pbg)
term.setTextColor(pfg)
term.clear()
term.setCursorPos(1,1)

if confirm then
	print("updating...")
	for k,v in pairs(ldb) do
		if not db[k] then
			print("'"..k.."' is not in main database; skipping")
		elseif v.version~=db[k].version then
			print(k..": "..v.version.." > "..db[k].version)
			ccr.install(k)
		end
	end
	print("update complete")
	
	for k,v in pairs(scrollwin.subitems) do
		if v.selected then
			if v.installed then
				ccr.remove(v.text,1)
			else
				ccr.install(v.text,1)
			end
		end
	end
end
