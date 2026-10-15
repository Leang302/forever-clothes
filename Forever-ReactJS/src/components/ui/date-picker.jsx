import { useState } from "react";
import { format, parse } from "date-fns";
import { CalendarIcon, XIcon } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/ui/calendar";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { cn } from "@/lib/utils";

const ISO = "yyyy-MM-dd";
const toDate = (value) => (value ? parse(value, ISO, new Date()) : undefined);

/**
 * shadcn/ui date picker (Popover + Calendar). `value` and `onChange` use "yyyy-MM-dd" strings ("" = no date),
 * the same format as the API's date filters. `min` / `max` limit the selectable range.
 */
export function DatePicker({ value, onChange, placeholder = "Pick a date", min, max, className }) {
  const [open, setOpen] = useState(false);
  const selected = toDate(value);
  const disabled = [min && { before: toDate(min) }, max && { after: toDate(max) }].filter(Boolean);

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <div className={cn("relative", className)}>
        <PopoverTrigger asChild>
          <Button
            type="button"
            variant="outline"
            className={cn("w-full justify-start pr-8 font-normal", !selected && "text-muted-foreground")}
          >
            <CalendarIcon className="size-4 opacity-60" />
            {selected ? format(selected, "d MMM yyyy") : placeholder}
          </Button>
        </PopoverTrigger>
        {selected && (
          <button
            type="button"
            onClick={() => onChange("")}
            aria-label="Clear date"
            className="absolute right-2 top-1/2 -translate-y-1/2 rounded p-0.5 text-muted-foreground hover:text-foreground"
          >
            <XIcon className="size-3.5" />
          </button>
        )}
      </div>
      <PopoverContent className="w-auto p-0" align="start">
        <Calendar
          mode="single"
          selected={selected}
          defaultMonth={selected}
          disabled={disabled}
          onSelect={(date) => {
            onChange(date ? format(date, ISO) : "");
            setOpen(false);
          }}
        />
      </PopoverContent>
    </Popover>
  );
}
