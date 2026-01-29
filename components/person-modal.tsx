"use client";

import React from "react";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerTitle,
} from "@/components/ui/drawer";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { createClient } from "@/lib/supabase/client";
import { useAuth } from "@/lib/auth-context";
import { Loader2, UserPlus } from "lucide-react";
import { useMediaQuery } from "@/hooks/use-media-query";

interface PersonModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSuccess: () => void;
}

function PersonForm({ onOpenChange, onSuccess }: Omit<PersonModalProps, 'open'>) {
  const { user } = useAuth();
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;

    setLoading(true);
    const supabase = createClient();

    try {
      const { error } = await supabase.from("people").insert({ 
        name: name.trim(),
        phone: phone.trim() || null,
        user_id: user?.id,
      });

      if (error) throw error;

      setName("");
      setPhone("");
      onOpenChange(false);
      onSuccess();
    } catch (error) {
      console.error("[v0] Error adding person:", error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4 pt-2">
      <div className="space-y-2">
        <Label htmlFor="name" className="text-sm font-medium">Name</Label>
        <Input
          id="name"
          placeholder="Enter person's name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          required
          className="h-11 sm:h-12"
        />
      </div>

      <div className="space-y-2">
        <Label htmlFor="phone" className="text-sm font-medium">Phone (Optional)</Label>
        <Input
          id="phone"
          placeholder="Enter phone number"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          className="h-11 sm:h-12"
        />
      </div>

      <div className="flex gap-2 sm:gap-3 pt-2">
        <Button
          type="button"
          variant="outline"
          className="flex-1 h-10 sm:h-12 bg-transparent"
          onClick={() => onOpenChange(false)}
        >
          Cancel
        </Button>
        <Button 
          type="submit" 
          className="flex-1 h-10 sm:h-12 bg-gradient-to-r from-blue-500 to-blue-600 hover:from-blue-600 hover:to-blue-700" 
          disabled={loading || !name.trim()}
        >
          {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
          Add Person
        </Button>
      </div>
    </form>
  );
}

export function PersonModal({ open, onOpenChange, onSuccess }: PersonModalProps) {
  const isDesktop = useMediaQuery("(min-width: 640px)");

  const HeaderIcon = () => (
    <div className="flex h-9 w-9 sm:h-10 sm:w-10 items-center justify-center rounded-xl bg-gradient-to-br from-blue-500 to-blue-600 text-white">
      <UserPlus className="h-4 w-4 sm:h-5 sm:w-5" />
    </div>
  );

  if (isDesktop) {
    return (
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <div className="flex items-center gap-3">
              <HeaderIcon />
              <DialogTitle className="text-xl">Add New Person</DialogTitle>
            </div>
          </DialogHeader>
          <PersonForm onOpenChange={onOpenChange} onSuccess={onSuccess} />
        </DialogContent>
      </Dialog>
    );
  }

  return (
    <Drawer open={open} onOpenChange={onOpenChange}>
      <DrawerContent className="px-4 pb-6">
        <DrawerHeader className="px-0">
          <div className="flex items-center gap-3">
            <HeaderIcon />
            <DrawerTitle className="text-xl">Add New Person</DrawerTitle>
          </div>
        </DrawerHeader>
        <PersonForm onOpenChange={onOpenChange} onSuccess={onSuccess} />
      </DrawerContent>
    </Drawer>
  );
}
